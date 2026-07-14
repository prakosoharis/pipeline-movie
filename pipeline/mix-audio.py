#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def run(command):
    subprocess.run(command, check=True)


def probe(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def duration_seconds(info):
    return float(info["format"]["duration"])


def has_audio(info):
    return any(stream.get("codec_type") == "audio" for stream in info["streams"])


def validate_manifest(root, manifest, probe_audio=True):
    output = manifest.get("output")
    shots = manifest.get("shots")
    if not isinstance(output, dict) or not isinstance(shots, list):
        raise SystemExit("Audio manifest requires output settings and a shots array")

    expected_ids = [f"shot-{number:02d}" for number in range(1, 23)]
    shot_ids = [shot.get("shot_id") for shot in shots]
    if shot_ids != expected_ids:
        raise SystemExit(
            "Audio manifest shots must contain shot-01 through shot-22 in order"
        )

    required_output = ("width", "height", "fps", "audio_sample_rate")
    missing_output = [key for key in required_output if key not in output]
    if missing_output:
        raise SystemExit(
            "Audio manifest output is missing: " + ", ".join(missing_output)
        )

    checked_audio = set()
    for shot in shots:
        layers = shot.get("layers")
        if not isinstance(layers, list) or not layers:
            raise SystemExit(f"{shot['shot_id']}: at least one audio layer is required")
        for layer in layers:
            relative = layer.get("file")
            if not isinstance(relative, str) or not relative:
                raise SystemExit(f"{shot['shot_id']}: audio layer has no file")
            audio_path = (root / relative).resolve()
            if root not in audio_path.parents:
                raise SystemExit(f"{shot['shot_id']}: audio path leaves project root")
            if not audio_path.is_file() or audio_path.stat().st_size == 0:
                raise SystemExit(f"Missing or empty audio for {shot['shot_id']}: {audio_path}")
            if audio_path not in checked_audio and probe_audio:
                if not has_audio(probe(audio_path)):
                    raise SystemExit(f"Audio asset has no audio stream: {audio_path}")
            checked_audio.add(audio_path)
            for key in ("gain_db", "start_seconds", "seek_seconds"):
                if key in layer:
                    try:
                        float(layer[key])
                    except (TypeError, ValueError):
                        raise SystemExit(
                            f"{shot['shot_id']}: {key} must be numeric"
                        ) from None

    return output, shots, len(checked_audio)


def validate_final(path, width, height, fps, sample_rate):
    info = probe(path)
    video = [stream for stream in info["streams"] if stream.get("codec_type") == "video"]
    audio = [stream for stream in info["streams"] if stream.get("codec_type") == "audio"]
    if len(video) != 1 or len(audio) != 1:
        raise SystemExit(f"Invalid assembled shot streams: {path}")
    if (video[0].get("width"), video[0].get("height")) != (width, height):
        raise SystemExit(f"Invalid assembled shot dimensions: {path}")
    if video[0].get("r_frame_rate") != f"{fps}/1":
        raise SystemExit(f"Invalid assembled shot frame rate: {path}")
    if audio[0].get("sample_rate") != str(sample_rate) or audio[0].get("channels") != 2:
        raise SystemExit(f"Invalid assembled shot audio format: {path}")


def main():
    parser = argparse.ArgumentParser(description="Mix approved audio layers into every raw shot.")
    parser.add_argument("--manifest", default="config/audio-manifest.json")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate the manifest and every referenced audio asset, then exit.",
    )
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    ffmpeg_available = shutil.which("ffmpeg") is not None
    ffprobe_available = shutil.which("ffprobe") is not None
    if not args.check:
        if not ffmpeg_available:
            raise SystemExit("Required command not found: ffmpeg")
        if not ffprobe_available:
            raise SystemExit("Required command not found: ffprobe")
    manifest_path = (root / args.manifest).resolve()
    if not manifest_path.is_file():
        raise SystemExit(f"Audio manifest not found: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    output_config, shots, audio_asset_count = validate_manifest(
        root, manifest, probe_audio=ffprobe_available
    )
    print(
        f"[mix-audio] Manifest validated: {len(shots)} shots, "
        f"{audio_asset_count} audio assets.",
        flush=True,
    )
    if args.check:
        if not ffprobe_available:
            print(
                "[mix-audio] ffprobe unavailable; asset paths were checked "
                "but audio streams were not probed.",
                flush=True,
            )
        return

    width = int(output_config["width"])
    height = int(output_config["height"])
    fps = int(output_config["fps"])
    sample_rate = int(output_config["audio_sample_rate"])

    for shot in shots:
        shot_id = shot["shot_id"]
        raw = root / "05-generated-video" / shot_id / f"{shot_id}-video-raw.mp4"
        final = root / "05-generated-video" / shot_id / f"{shot_id}-final.mp4"
        temporary = final.with_name(f".{final.name}.mixing.tmp.mp4")
        if not raw.is_file() or raw.stat().st_size == 0:
            raise SystemExit(f"Missing or empty raw video: {raw}")
        if final.exists() and not args.force:
            validate_final(final, width, height, fps, sample_rate)
            print(f"[mix-audio] {shot_id}: skip existing {final}", flush=True)
            continue

        info = probe(raw)
        duration = duration_seconds(info)
        final.parent.mkdir(parents=True, exist_ok=True)
        temporary.unlink(missing_ok=True)
        command = ["ffmpeg", "-nostdin", "-y", "-i", str(raw)]
        layers = shot.get("layers", [])
        for layer in layers:
            audio_path = root / layer["file"]
            if not audio_path.is_file():
                raise SystemExit(f"Missing audio for {shot_id}: {audio_path}")
            if layer.get("loop", False):
                command.extend(["-stream_loop", "-1"])
            command.extend(["-i", str(audio_path)])

        filters = [
            f"[0:v:0]scale={width}:{height}:force_original_aspect_ratio=increase,"
            f"crop={width}:{height},fps={fps},setsar=1[vout]"
        ]
        mix_labels = []
        if has_audio(info):
            filters.append(
                f"[0:a:0]aresample={sample_rate},aformat=sample_fmts=fltp:"
                f"channel_layouts=stereo,apad,atrim=0:{duration:.6f}[base]"
            )
        else:
            filters.append(
                f"anullsrc=r={sample_rate}:cl=stereo,atrim=0:{duration:.6f}[base]"
            )
        mix_labels.append("[base]")

        for index, layer in enumerate(layers, start=1):
            label = f"layer{index}"
            start_ms = round(float(layer.get("start_seconds", 0)) * 1000)
            seek = float(layer.get("seek_seconds", 0))
            gain = float(layer.get("gain_db", 0))
            filters.append(
                f"[{index}:a:0]atrim=start={seek:.6f},asetpts=PTS-STARTPTS,"
                f"aresample={sample_rate},aformat=sample_fmts=fltp:channel_layouts=stereo,"
                f"volume={gain}dB,adelay={start_ms}|{start_ms},apad,"
                f"atrim=0:{duration:.6f}[{label}]"
            )
            mix_labels.append(f"[{label}]")

        filters.append(
            "".join(mix_labels)
            + f"amix=inputs={len(mix_labels)}:duration=longest:dropout_transition=0:normalize=0,"
            + f"alimiter=limit=0.95,atrim=0:{duration:.6f}[aout]"
        )
        command.extend(
            [
                "-filter_complex",
                ";".join(filters),
                "-map",
                "[vout]",
                "-map",
                "[aout]",
                "-c:v",
                "libx264",
                "-preset",
                "medium",
                "-crf",
                "18",
                "-profile:v",
                "high",
                "-pix_fmt",
                "yuv420p",
                "-g",
                str(fps * 2),
                "-c:a",
                "aac",
                "-b:a",
                "192k",
                "-ar",
                str(sample_rate),
                "-ac",
                "2",
                "-movflags",
                "+faststart",
                str(temporary),
            ]
        )
        print(f"[mix-audio] {shot_id}: {duration:.3f}s, {len(layers)} layers", flush=True)
        try:
            run(command)
            validate_final(temporary, width, height, fps, sample_rate)
            os.replace(temporary, final)
        finally:
            temporary.unlink(missing_ok=True)

    print("[mix-audio] All 22 final shots are ready.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        print(f"[mix-audio] ERROR: command failed with exit code {exc.returncode}", file=sys.stderr)
        raise SystemExit(exc.returncode)
