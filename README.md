# MIMPI YANG MENGEJAR - AI Film Production Pack

Short film thriller/aksi psikologis berdurasi target 150-180 detik.
Project ini memakai pendekatan Hybrid AI Film Production: creative
pre-production dilakukan manual dengan ChatGPT dan human approval,
sementara video POC dirancang memakai Wan2.2 self-hosted dan media
assembly headless.

Spesifikasi kreatif: 2.39:1 Cinemascope | 24fps | Bahasa Indonesia
netral | 2 karakter | 1080p/4K | neo-noir thriller.

---

## Tujuan Project

Repository ini adalah production pack dokumentasi untuk membuat film
pendek "Mimpi Yang Mengejar" secara AI-assisted, human-in-the-loop, dan
asset-driven.

Tujuan saat ini:
- menjaga source of truth kreatif;
- mengunci referensi karakter, keyframe, dialog, audio plan, dan shot
  plan;
- menjalankan pipeline hybrid secara manual dan human-in-the-loop;
- menyiapkan audio asset approval dan production media assembly.

Pipeline deployment Wan2.2 sudah tersedia sebagai script manual. Adapter
model, runtime registry, dan AI Director masih dokumentasi future dan belum
diimplementasikan. Jangan membuat output video palsu, backend, Dockerfile,
atau otomasi baru tanpa instruksi terpisah.

---

## Struktur Project

```text
project-film/
├── 01-project-bible/
│   ├── project-context.txt
│   ├── story.txt
│   ├── screenplay.txt
│   └── character-bible.txt
├── docs/
│   └── architecture/
│       ├── README.md
│       ├── ADR-000-project-principles.md
│       ├── ADR-001-chatgpt-images.md
│       ├── ADR-002-wan22-self-hosted-video.md
│       ├── ADR-003-audio-tooling.md
│       ├── ADR-004-headless-ffmpeg-assembly.md
│       ├── ADR-005-davinci-optional-only.md
│       ├── ADR-006-human-approval-gates.md
│       ├── ADR-007-ai-director-separation.md
│       ├── ADR-0005-model-adapter-architecture.md
│       └── MODEL-REGISTRY.md
├── 02-character/
│   ├── character-image-prompts.txt
│   ├── adam/
│   ├── sang-pengejar/
│   ├── set-props/
│   └── shot-images/
├── 03-shots/
│   ├── shot-list.txt
│   └── prompts/
├── 04-audio/
│   ├── audio-production-workflow.md
│   ├── dialogue/
│   ├── ambience/
│   ├── sound-effects/
│   └── music/
├── 05-generated-video/
│   └── README.md
├── 06-editing/
│   └── headless-media-assembly.md
├── 07-final/
└── 08-quality-control/
    ├── image-validation-checklist.txt
    ├── video-shot-validation-checklist.txt
    ├── final-quality-control-prompt.txt
    └── asset-status-report.txt
├── pipeline/
│   ├── adapters/
│   ├── benchmarks/
│   ├── runtimes/
│   ├── manifest.json
│   ├── preflight.sh
│   ├── setup-poc.sh
│   ├── setup-production-models.sh
│   ├── run-poc.sh
│   └── run-production.sh
```

---

## Status Aset Saat Ini

Selesai / approved:
- project bible, story, screenplay, character bible;
- master visual Adam;
- master visual Sang Pengejar;
- set kamar dan insert fedora;
- 22 keyframe image untuk shot 01-22;
- prompt video per shot;
- master text dialog Bahasa Indonesia;
- prompt ambience, SFX, dan music.

Sedang / berikutnya:
- dialogue generation dan approval dialogue master;
- ambience, Foley/SFX, dan music asset generation atau approval;
- final audio mix per shot dan film;
- validasi shot video per output;
- production render seluruh shot.

Sudah berjalan:
- environment Wan2.2 S2V/TI2V tervalidasi di Vast.ai;
- Shot 15 S2V berhasil dirender dan disetujui untuk melanjutkan fase
  production;
- model TI2V production sudah disiapkan setelah approval Shot 15.

Belum selesai:
- seluruh 22 shot production;
- final audio mix ambience, SFX, dan music;
- final film assembly ke `07-final/film-final.mp4`.

Jangan menandai asset final selesai sebelum file finalnya tersedia dan
lolos approval.

---

## Pipeline Terbaru

Keputusan arsitektur formal berada di `docs/architecture/`. Ringkasan di
README ini harus tetap selaras dengan ADR tersebut.

### 1. Creative & Visual Pre-production

ChatGPT digunakan secara manual untuk:
- ide cerita;
- project bible;
- screenplay;
- dialog Bahasa Indonesia;
- shot list;
- prompt per shot;
- master character;
- character reference sheet;
- keyframe image setiap shot.

Semua gambar harus melalui human approval sebelum dipakai sebagai input
video generation.

### 2. Audio Asset Creation

ElevenLabs digunakan untuk dialogue voice, ambience, Foley, dan sound
effects. Music provider terpisah dan opsional: musik dapat berasal dari
ElevenLabs Music, Suno, atau library berlisensi.

Dialogue master harus dibuat, disetujui, dan dikunci sebelum shot dialog
diproses dengan Wan2.2-S2V. Dialogue master harus bersih: tanpa musik,
tanpa ambience, tanpa SFX, dan tidak boleh diubah tempo, jeda, atau
durasinya setelah dipakai untuk lip-sync.

Detail workflow ada di `04-audio/audio-production-workflow.md`.

### 3. Self-hosted Video Rendering

Video generation memakai keluarga Wan2.2 self-hosted:
- Wan2.2 I2V atau TI2V untuk action shot, establishing shot, insert
  shot, dan shot tanpa dialog;
- Wan2.2-S2V untuk shot dialog yang membutuhkan lip-sync.

Wan2.2 adalah video-generation engine. Wan2.2 bukan sistem final mixing
untuk seluruh film.

### 4. Media Assembly

FFmpeg digunakan secara internal dan headless di pipeline self-hosted.
Pengguna tidak harus menjalankan FFmpeg secara manual.

Arsitektur media assembly menargetkan tanggung jawab berikut:
- muxing dialogue audio ke video jika output model belum memiliki audio;
- mencampur ambience, Foley, SFX, dan music untuk setiap shot;
- menjaga sinkronisasi dialogue master;
- menyambungkan 22 shot final sesuai timeline manifest;
- menghasilkan `scene-final.mp4` atau `07-final/film-final.mp4`;
- validasi dasar dengan ffprobe.

Production runner menjalankan media assembly secara otomatis setelah semua
raw shot tersedia. Mapping audio berasal dari `config/audio-manifest.json`;
runner mempertahankan dialogue S2V sebagai base audio, menambahkan ambience,
Foley/SFX, nonverbal, dan music, lalu menormalisasi seluruh shot ke format
video/audio yang sama sebelum final assembly.

FFmpeg bukan AI dan tidak membuat lip-sync. Lip-sync dibuat oleh
Wan2.2-S2V berdasarkan final dialogue master.

Detail rancangan ada di `06-editing/headless-media-assembly.md`.

---

## I2V, S2V, dan Media Assembly

I2V/TI2V:
- input utama: approved keyframe/character image dan prompt shot;
- output: visual shot raw;
- ambience, Foley, SFX, dan music ditambahkan di media assembly.

S2V:
- input utama: approved character/keyframe image;
- input audio: final dialogue master;
- output: video lip-sync berdasarkan audio tersebut;
- workflow self-hosted boleh memasukkan audio dialogue yang sama ke MP4
  output secara otomatis.

Media assembly yang diimplementasikan:
- menerima raw video dari Wan2.2;
- menjaga dialogue master tetap sinkron;
- menambahkan ambience, Foley, SFX, dan music;
- menghasilkan final MP4 per shot dan final film.

Satu perintah production menghasilkan raw shot yang belum tersedia, audio
mix per shot, dan film final lengkap:

```sh
bash pipeline/run-production.sh --env-file config/poc.env
```

Urutan internalnya adalah:

```text
validate config/audio-manifest.json and all referenced audio
        -> generate or resume raw Wan2.2 shots
        -> pipeline/mix-audio.sh
        -> 22 x shot-XX-final.mp4
        -> pipeline/assemble-final.sh
        -> 07-final/film-final.mp4
```

Jika proses dijalankan ulang, raw MP4 yang valid dilewati. Audio mix dan
final assembly dibuat ulang secara atomik sehingga file lama tidak dianggap
berhasil bila FFmpeg berhenti di tengah proses.

---

## Output Per Shot

Struktur output yang direncanakan per shot:

```text
05-generated-video/
└── shot-XX/
    ├── shot-XX-video-raw.mp4
    ├── shot-XX-final.mp4
    ├── shot-XX-metadata.json
    └── shot-XX-validation.md
```

`shot-XX-video-raw.mp4` adalah output langsung video-generation engine.
`shot-XX-final.mp4` adalah shot yang sudah memiliki audio final yang
diperlukan. Metadata mencatat input image, dialogue, ambience, SFX,
music, model, prompt, seed, duration, dan status. Validation mencatat
hasil human atau automated review.

Runner saat ini menyimpan raw MP4 dan metadata; file final per shot serta
mix audio lengkap harus dianggap belum tersedia sampai benar-benar dibuat
dan lolos approval.

---

## Final Film Assembly

Final film dibangun dari seluruh shot yang sudah approved:

```text
shot-01-final.mp4
shot-02-final.mp4
...
shot-22-final.mp4
        ↓
FFmpeg assembly
        ↓
07-final/film-final.mp4
```

Urutan dan timing berasal dari timeline manifest, bukan ditulis permanen
di command FFmpeg.

Contoh schema dokumentasi:

```json
{
  "project_id": "mimpi-yang-mengejar",
  "shots": [
    {
      "shot_id": "shot-01",
      "file": "05-generated-video/shot-01/shot-01-final.mp4",
      "order": 1,
      "transition": "cut"
    }
  ]
}
```

---

## Human Approval Gates

Human approval wajib pada:
1. screenplay approval;
2. master character approval;
3. keyframe image approval;
4. dialogue master approval;
5. generated shot approval;
6. final film approval.

Tidak boleh ada keyframe yang otomatis dikirim ke Wan2.2 tanpa status
APPROVED. Tidak boleh ada shot yang otomatis masuk final film tanpa
status APPROVED.

Lihat juga `docs/architecture/ADR-006-human-approval-gates.md`.

---

## DaVinci Resolve Policy

DaVinci Resolve bukan bagian wajib dari pipeline utama. DaVinci hanya
fallback opsional untuk:
- koreksi manual;
- color grading manual;
- perbaikan audio manual;
- fine editing;
- kebutuhan editorial yang tidak dapat diselesaikan otomatis.

Pipeline utama harus tetap bisa berjalan headless tanpa DaVinci Resolve.

Lihat juga `docs/architecture/ADR-005-davinci-optional-only.md`.

---

## Key Decisions Locked

| Item | Decision |
|------|----------|
| Judul | "Mimpi Yang Mengejar" |
| Genre | Thriller/Aksi psikologis |
| Durasi target | 150-180 detik |
| Durasi shot mentah | sekitar 97 detik minimum sebelum pacing/editing |
| Aspect | 2.39:1 Cinemascope |
| Tone | Aksi cepat -> dread -> twist |
| Twist | Hybrid C->A: dread + jumpscare + fedora epilog |
| Multi-tafsir | Tidak dieksplisit |
| Karakter | Adam dan Sang Pengejar |
| Dialog | Bahasa Indonesia netral, minimum |
| Tagline | "Hati-hatilah dengan mimpimu." |

---

## Langkah Berikutnya

1. Approve dialogue master untuk semua beat dialog dan vokal non-verbal.
2. Generate/approve ambience, Foley/SFX, dan music optional.
3. Jalankan production render dari `config/production-manifest.json`.
4. Lengkapi per-shot audio mix dan validasi final shot.
5. Jalankan final FFmpeg assembly dan final quality control.

---

## Roadmap Model

### v1 Current Champion

```text
ChatGPT Images
      |
      v
Wan2.2
      |
      v
Final MP4
```

Wan2.2 tetap menjadi model champion dan pipeline production saat ini tidak
berubah.

### Future Architecture

```text
ChatGPT Images
      |
      v
Model Adapter
      |
      v
Renderer
      |
      v
Final MP4
```

Model adapter akan menjadi boundary untuk Wan2.2, LTX Video, HunyuanVideo,
Open-Sora, dan kandidat future lainnya. Arah ini bersifat dokumentatif dan
belum diimplementasikan. Lihat
`docs/architecture/ADR-0005-model-adapter-architecture.md` dan
`docs/architecture/MODEL-REGISTRY.md`.
