# Audio Production Workflow

Dokumen ini menjelaskan workflow audio untuk "Mimpi Yang Mengejar" dalam
arsitektur Hybrid AI Film Production. Ini dokumentasi rancangan, bukan
implementasi pipeline.

Rujukan arsitektur:
- `docs/architecture/ADR-003-audio-tooling.md`
- `docs/architecture/ADR-006-human-approval-gates.md`

## Tujuan

Audio dibuat sebagai asset terpisah agar dialogue master, ambience,
Foley, SFX, dan music bisa disetujui secara manusiawi sebelum dipakai
untuk Wan2.2-S2V atau media assembly.

## Kategori Audio

Dialogue:
- dialog terucap Adam sesuai `04-audio/dialogue/dialogue-indonesia.txt`;
- dipakai sebagai source utama lip-sync untuk shot S2V;
- harus bersih, mono/center-friendly, tanpa ambience, tanpa SFX, tanpa
  music.

Non-verbal vocal:
- napas, erangan, swallow, sigh, gasp, shock vocal;
- disimpan terpisah dari dialogue beat;
- boleh dipakai sebagai cue performa atau layer audio final.

Ambience:
- room tone/space bed untuk gang, underpass, dan kamar;
- mengacu ke `04-audio/ambience/ambience-prompts.txt`;
- tidak boleh mengandung musik, dialog, footsteps jelas, atau one-shot
  foreground yang mengganggu.

Foley:
- bunyi performa fisik dekat seperti cloth movement, body movement,
  hand contact, atau prop handling tambahan bila diperlukan;
- dibuat terpisah agar bisa disinkronkan di media assembly.

SFX:
- efek spesifik seperti footsteps, gunshot, debris, drink water, door
  creak, dan glass set down;
- mengacu ke `04-audio/sound-effects/sound-effect-prompts.txt`.

Music:
- optional dan minimal;
- mengacu ke `04-audio/music/music-prompts.txt`;
- provider dapat berupa ElevenLabs Music, Suno, atau library berlisensi.
  Project tidak dikunci pada satu music provider.

## Tool Yang Digunakan

ElevenLabs digunakan untuk:
- dialogue voice;
- ambience;
- Foley;
- sound effects.

Music provider bersifat terpisah dan opsional:
- ElevenLabs Music;
- Suno;
- licensed music library.

Wan2.2-S2V memakai dialogue master untuk membuat lip-sync. Wan2.2-S2V
bukan tempat untuk menambahkan ambience, Foley, SFX, atau music final.

FFmpeg media assembly memakai asset audio final untuk muxing dan mixing
per shot secara internal/headless.

## Dialogue Master Lock

Dialogue master harus dibuat dan disetujui sebelum shot dialog diproses
dengan Wan2.2-S2V.

Aturan dialogue master:
- audio bersih;
- tidak mengandung music;
- tidak mengandung ambience;
- tidak mengandung Foley;
- tidak mengandung sound effect;
- tidak diubah tempo, jeda, pitch, atau durasinya setelah dipakai untuk
  lip-sync;
- file yang sama harus menjadi referensi S2V dan referensi sync saat
  media assembly.

Larangan penting:
- jangan memasukkan ambience ke dialogue master;
- jangan memasukkan ledakan, gunshot, door creak, atau SFX lain ke
  dialogue master;
- jangan membuat satu mixed track panjang lalu menggunakannya sebagai
  source S2V.

## Penggunaan Audio Dalam S2V

Untuk shot dialog:
1. pilih approved keyframe/character image;
2. pilih final dialogue master untuk beat terkait;
3. jalankan Wan2.2-S2V dengan image + dialogue master;
4. output raw disimpan sebagai `shot-XX-video-raw.mp4`;
5. jika output S2V sudah membawa audio, audio tersebut harus sama dengan
   dialogue master yang disetujui;
6. jika output S2V tidak membawa audio, FFmpeg dapat melakukan muxing
   dialogue master yang sama pada media assembly.

Shot dialog utama:
- S02 -> BEAT 1;
- S06 -> BEAT 2;
- S11 -> BEAT 3;
- S12 -> BEAT 4;
- S15 -> BEAT 5;
- S21 -> BEAT 6.

S15 adalah prioritas lip-sync tertinggi karena memuat kalimat kunci:
"Untunglah... hanya mimpi."

## Penggunaan Ambience dan SFX Dalam Media Assembly

Ambience, Foley, SFX, dan music tidak dikunci ke raw video Wan2.2 I2V
atau TI2V. Asset ini ditambahkan saat media assembly.

Media assembly bertanggung jawab untuk:
- menjaga dialogue master tetap sinkron;
- menambahkan ambience sesuai lokasi;
- menambahkan Foley dan SFX sesuai aksi;
- menambahkan music optional sesuai cue;
- menghasilkan `shot-XX-final.mp4`.

## Naming Convention

Nama di bawah adalah target final setelah asset dipilih, disetujui, dan
dikunci. File hasil generate awal boleh berupa `.mp3` dengan basename
yang sama sebagai kandidat, tetapi belum dianggap final/LOCKED sampai
lolos QC dan approval.

Dialogue:
- `04-audio/dialogue/beat-01-tidak-tidak.wav`
- `04-audio/dialogue/beat-02-tolong.wav`
- `04-audio/dialogue/beat-03-siapa-kamu.wav`
- `04-audio/dialogue/beat-04-tidaaa-cut.wav`
- `04-audio/dialogue/beat-05-untunglah-hanya-mimpi.wav`
- `04-audio/dialogue/beat-06-tidaaak-cut.wav`

Non-verbal vocal:
- `04-audio/dialogue/nv-01-pant.wav`
- `04-audio/dialogue/nv-02-grunt.wav`
- `04-audio/dialogue/nv-03-swallow.wav`
- `04-audio/dialogue/nv-04-sigh.wav`
- `04-audio/dialogue/nv-05-gasp.wav`
- `04-audio/dialogue/nv-06-shock.wav`

Ambience:
- `04-audio/ambience/amb-001-alley-dust.wav`
- `04-audio/ambience/amb-002-underpass-echo.wav`
- `04-audio/ambience/amb-003-bedroom-night.wav`

SFX:
- `04-audio/sound-effects/sfx-001-footsteps-chase.wav`
- `04-audio/sound-effects/sfx-002-footsteps-pengejar.wav`
- `04-audio/sound-effects/sfx-003-footsteps-wood.wav`
- `04-audio/sound-effects/sfx-004-gunshot-concrete.wav`
- `04-audio/sound-effects/sfx-005a-gunshot-main-outdoor.wav`
- `04-audio/sound-effects/sfx-005b-gunshot-main-indoor.wav`
- `04-audio/sound-effects/sfx-006-debris-concrete.wav`
- `04-audio/sound-effects/sfx-007-drink-water.wav`
- `04-audio/sound-effects/sfx-008-door-creak.wav`
- `04-audio/sound-effects/sfx-009-glass-set-down.wav`
- `04-audio/sound-effects/sfx-010-impact-body-fall.wav`

Music:
- `04-audio/music/mus-001-drone-low.wav`
- `04-audio/music/mus-002-sting-high.wav`

## Approval Status

Recommended statuses:
- `PLANNED`;
- `GENERATED`;
- `REVISE`;
- `REJECTED`;
- `APPROVED`;
- `LOCKED`.

Dialogue master must reach `APPROVED` and then `LOCKED` before S2V.
Ambience, Foley, SFX, and music must be `APPROVED` before final media
assembly.

## Hubungan Audio Asset Dengan Shot ID

Setiap `shot-XX-metadata.json` harus mencatat audio asset yang dipakai:
- dialogue file, bila ada;
- non-verbal vocal file, bila ada;
- ambience file;
- Foley file, bila ada;
- SFX file;
- music file, bila ada;
- approval status masing-masing.

Shot tanpa dialog tetap harus mencatat ambience dan SFX bila dipakai.
Shot S2V harus mencatat source dialogue master yang sama dengan audio
yang digunakan untuk lip-sync.

## QC Audio

Sebelum audio dipakai:
- dialogue bersih dan jelas;
- tidak ada ambience/SFX/music di dialogue master;
- file tidak clipping;
- sample rate final disarankan 48kHz;
- durasi dialogue cocok dengan shot terkait;
- SFX tidak menutupi dialogue;
- ambience cukup rendah untuk ruang dialog;
- music optional tidak mengunci provider dan tidak mengambil alih film.
