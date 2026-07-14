# ADR-004: FFmpeg Headless Assembly

Status: Accepted

## Context

Project membutuhkan proses internal untuk menyatukan video raw, dialogue,
ambience, Foley, SFX, music optional, dan 22 final shot menjadi final MP4.

## Decision

FFmpeg digunakan secara internal/headless untuk:

- muxing;
- audio mixing;
- concatenation;
- encoding;
- output final MP4;
- ffprobe validation.

## Constraints

- FFmpeg tidak membuat lip-sync.
- Pengguna tidak harus menjalankan FFmpeg secara manual.
- Dialogue master yang dipakai S2V harus tetap sinkron di media assembly.
- Urutan final film berasal dari timeline manifest, bukan command hardcoded.

## Consequences

- `06-editing/headless-media-assembly.md` menjadi rancangan utama media
  assembly.
- Pipeline utama harus tetap berjalan tanpa NLE/DaVinci.
- Final film hanya dibuat dari shot final yang APPROVED.
