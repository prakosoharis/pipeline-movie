# Model Registry

Dokumen ini mendefinisikan format konseptual registry model untuk fase future.
Registry belum executable dan belum menjadi input runtime pipeline.

## Proposed Entry Format

```yaml
id: <stable-model-id>
display_name: <human-readable-name>
provider: <repository-or-owner>
status: CANDIDATE | CHAMPION | RETIRED
capabilities:
  - <capability>
adapter: <future-adapter-id>
runtime: <future-runtime-id>
tasks:
  - <supported-task>
checkpoint: <checkpoint-reference>
benchmark_status: NOT_RUN | RUNNING | PASSED | FAILED
notes: <human decision notes>
```

## Example Entries

### `wan22-s2v`

```yaml
id: wan22-s2v
display_name: Wan2.2 S2V 14B
provider: Wan-Video/Wan2.2
status: CHAMPION
capabilities:
  - DIALOGUE_VIDEO
  - LIP_SYNC
adapter: wan22
runtime: wan22-self-hosted
tasks:
  - S2V
```

### `ltx-video`

```yaml
id: ltx-video
display_name: LTX Video
provider: open-source
status: CANDIDATE
capabilities:
  - IMAGE_TO_VIDEO
  - AUDIO_VIDEO_NATIVE
adapter: ltx-video
runtime: ltx-video-self-hosted
tasks:
  - I2V
  - AUDIO_VIDEO
```

### `hunyuan-video`

```yaml
id: hunyuan-video
display_name: HunyuanVideo
provider: open-source
status: CANDIDATE
capabilities:
  - IMAGE_TO_VIDEO
adapter: hunyuan-video
runtime: hunyuan-video-self-hosted
tasks:
  - I2V
```

## Registry Rules

- registry entry tidak berarti model otomatis dipakai;
- `CHAMPION` hanya boleh ditetapkan setelah benchmark dan human approval;
- capability harus dibuktikan oleh benchmark;
- checkpoint, adapter, runtime, dan commit harus dapat dilacak;
- registry tidak menggantikan `config/production-manifest.json`.

## Golden Benchmark

Semua kandidat dibandingkan menggunakan lima shot benchmark yang sama:

1. dialogue close-up;
2. running action;
3. emotional acting;
4. camera movement;
5. hands / object interaction.

Metrics yang dicatat:

- identity consistency;
- lip sync;
- motion quality;
- prompt adherence;
- render time;
- cost per accepted shot.

Hasil benchmark mencatat model version, checkpoint, runtime, GPU, prompt,
input asset, seed bila tersedia, durasi, dan keputusan accepted atau rejected.
