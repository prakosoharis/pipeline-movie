# ADR-002: Wan2.2 Self-hosted Video

Status: Accepted for POC

## Context

Project membutuhkan video generation untuk 22 shot dengan kombinasi shot
aksi, insert, establishing, dan dialog/lip-sync.

## Decision

Wan2.2 self-hosted di GPU rental digunakan untuk POC video.

Penggunaan:

- Wan2.2 I2V/TI2V untuk action shot, establishing shot, insert shot, dan
  shot tanpa dialog.
- Wan2.2-S2V untuk dialogue shot dan lip-sync.

## Constraints

- Wan2.2 adalah video-generation engine, bukan final media mixer.
- Wan2.2-S2V membuat lip-sync berdasarkan final dialogue master.
- Approved image/keyframe wajib sebelum render.
- Dialogue master wajib APPROVED dan LOCKED sebelum S2V.

## Not Final Yet

Pemilihan tetap harus divalidasi melalui POC:

- kualitas visual;
- kualitas lip-sync;
- waktu render;
- biaya per accepted shot;
- reliabilitas;
- tingkat regenerate.

## Consequences

- Video output raw disimpan sebagai `shot-XX-video-raw.mp4`.
- Final audio, ambience, SFX, music, dan concatenation ditangani media
  assembly.
