# ADR-003: Audio Tooling

Status: Accepted for POC

## Context

Film bergantung pada dialog minimal, vokal non-verbal, ambience, SFX,
dan music optional. Audio harus siap sebelum shot dialog diproses S2V.

## Decision

- ElevenLabs Text to Speech digunakan untuk dialogue.
- ElevenLabs Sound Effects digunakan untuk ambience, Foley, dan SFX.
- Penyedia musik tetap opsional dan tidak dikunci.
- Rekaman manusia tetap boleh dipakai jika lebih natural.

## Constraints

- Dialogue master harus bersih dan dikunci sebelum S2V.
- Dialogue master tidak boleh mengandung ambience, Foley, SFX, atau music.
- Ambience, SFX, dan music tidak dimasukkan ke dialogue master.
- Setelah dipakai untuk S2V, tempo, jeda, dan durasi dialogue master tidak
  boleh diubah.

## Consequences

- `04-audio/audio-production-workflow.md` menjadi workflow audio utama.
- File `.mp3` yang ada saat ini diperlakukan sebagai kandidat/take awal
  sampai dipilih dan ditandai LOCKED sebagai dialogue master final.
- Music provider tetap optional dan provider-agnostic.
