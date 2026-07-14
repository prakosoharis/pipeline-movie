# Headless Media Assembly

Dokumen ini menjelaskan media assembly headless yang diimplementasikan untuk
"Mimpi Yang Mengejar".

Rujukan arsitektur:
- `docs/architecture/ADR-004-headless-ffmpeg-assembly.md`
- `docs/architecture/ADR-005-davinci-optional-only.md`
- `docs/architecture/ADR-006-human-approval-gates.md`

## Tujuan Media Assembly

Media assembly mengubah output raw per shot menjadi final shot MP4, lalu
menyambungkan 22 final shot yang sudah APPROVED menjadi film final.

Pipeline utama harus dapat berjalan headless tanpa DaVinci Resolve.
FFmpeg digunakan sebagai komponen internal pipeline self-hosted.
Pengguna tidak harus menjalankan FFmpeg secara manual.

## Istilah

Muxing:
- memasukkan stream audio ke container video tanpa mengubah isi kreatif;
- contoh: menambahkan dialogue master ke output S2V bila raw MP4 belum
  membawa audio.

Mixing:
- mencampur dialogue, ambience, Foley, SFX, dan music menjadi audio final
  per shot;
- harus menjaga dialogue tetap jelas dan sinkron.

Lip-sync:
- sinkronisasi gerak mulut dengan audio dialogue;
- dibuat oleh Wan2.2-S2V berdasarkan final dialogue master;
- tidak dibuat oleh FFmpeg.

Concatenation:
- menyambungkan `shot-01-final.mp4` sampai `shot-22-final.mp4` sesuai
  timeline manifest;
- dilakukan setelah semua shot yang dibutuhkan berstatus APPROVED.

## Tanggung Jawab Wan dan FFmpeg

Wan2.2 I2V/TI2V:
- menghasilkan visual raw untuk action shot, establishing shot, insert
  shot, dan shot tanpa dialog;
- output disimpan sebagai `shot-XX-video-raw.mp4`.

Wan2.2-S2V:
- menerima approved image dan final dialogue master;
- menghasilkan video lip-sync berdasarkan audio tersebut;
- workflow self-hosted boleh menyertakan audio dialogue yang sama ke MP4
  output.

FFmpeg:
- muxing dialogue audio bila raw MP4 belum memiliki audio;
- mixing ambience, Foley, SFX, dan music;
- menjaga sync dialogue master;
- menyambungkan final shot sesuai timeline manifest;
- menghasilkan `scene-final.mp4` atau `07-final/film-final.mp4`;
- menjalankan validasi dasar via ffprobe.

FFmpeg bukan AI dan tidak membuat lip-sync.

## Alur Per Shot

1. Pastikan keyframe/character image berstatus APPROVED.
2. Untuk shot dialog, pastikan dialogue master berstatus APPROVED dan
   LOCKED.
3. Render raw video dengan Wan2.2:
   - I2V/TI2V untuk shot tanpa lip-sync;
   - S2V untuk shot dialog yang butuh lip-sync.
4. Simpan raw video:

```text
05-generated-video/shot-XX/shot-XX-video-raw.mp4
```

5. Jalankan media assembly per shot:
   - mux dialogue bila perlu;
   - mix ambience, Foley, SFX, dan music;
   - pertahankan timing dialogue master;
   - export final shot.

Implementasi:
- mapping layer: `config/audio-manifest.json`;
- mixing/normalisasi: `pipeline/mix-audio.sh`;
- final concatenation: `pipeline/assemble-final.sh`;
- orkestrasi end-to-end: `pipeline/run-production.sh`.

## Pengaturan Audio Pipeline

Setiap entri shot di `config/audio-manifest.json` mempunyai array `layers`.
Layer dapat berupa ambience, Foley/SFX, music, atau vocal nonverbal:

```json
{
  "file": "04-audio/sound-effects/sfx-008-door-creak.wav",
  "gain_db": -8,
  "start_seconds": 0,
  "seek_seconds": 0,
  "loop": false
}
```

Arti field:
- `file`: path asset audio relatif terhadap root repository;
- `gain_db`: volume layer dalam desibel;
- `start_seconds`: waktu layer mulai di dalam shot;
- `seek_seconds`: posisi awal yang diambil dari file sumber;
- `loop`: ulangi asset sampai durasi shot terpenuhi.

Dialogue utama shot S2V tidak perlu diduplikasi sebagai layer. Dialogue
berasal dari field `audio` di `config/production-manifest.json`, digunakan
Wan2.2-S2V untuk lip-sync, lalu dipertahankan sebagai base audio saat mixing.
Jika raw S2V tidak membawa stream audio, production runner memasukkan dialogue
master yang sama tanpa menjalankan inference ulang.

Mengubah ambience, SFX, nonverbal, music, gain, atau timing hanya memerlukan
media assembly ulang. Mengubah dialogue master setelah S2V memerlukan render
S2V dan human validation ulang karena gerak bibir terikat pada audio tersebut.

6. Simpan final shot dan report:

```text
05-generated-video/shot-XX/shot-XX-final.mp4
05-generated-video/shot-XX/shot-XX-metadata.json
05-generated-video/shot-XX/shot-XX-validation.md
```

7. Human review memberi status `APPROVED`, `REVISE`, `REGENERATE`, atau
   `REJECTED`.

## Alur Final Film

Final film dibangun dari 22 shot final yang tercantum dalam audio manifest.
Human review tetap wajib sebelum output diberi status final APPROVED:

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

Shot yang belum APPROVED tidak boleh masuk manifest final.

## Timeline Manifest Example

Urutan dan timing berasal dari timeline manifest, bukan ditulis permanen
di command FFmpeg.

```json
{
  "project_id": "mimpi-yang-mengejar",
  "output": "07-final/film-final.mp4",
  "shots": [
    {
      "shot_id": "shot-01",
      "file": "05-generated-video/shot-01/shot-01-final.mp4",
      "order": 1,
      "transition": "cut"
    },
    {
      "shot_id": "shot-02",
      "file": "05-generated-video/shot-02/shot-02-final.mp4",
      "order": 2,
      "transition": "cut"
    }
  ]
}
```

Manifest schema minimum:
- `project_id`;
- `output`;
- `shots`;
- `shot_id`;
- `file`;
- `order`;
- `transition`.

Optional future fields:
- `in`;
- `out`;
- `duration`;
- `audio_ducking`;
- `loudness_target`;
- `notes`;
- `approval_status`.

## Output Folder Convention

Per shot:

```text
05-generated-video/
└── shot-XX/
    ├── shot-XX-video-raw.mp4
    ├── shot-XX-final.mp4
    ├── shot-XX-metadata.json
    └── shot-XX-validation.md
```

Final:

```text
07-final/
└── film-final.mp4
```

## Sync Rules

Dialogue:
- dialogue master used for S2V must be the same source used in media
  assembly;
- no tempo change, speed change, or duration change after S2V;
- if a dialogue track needs replacement, the S2V shot must be
  regenerated or explicitly revalidated.

SFX:
- gunshots and abrupt screams must remain frame-accurate to action;
- footsteps can be edited for sync but must not change character
  identity.

Ambience:
- ambience may loop, crossfade, and duck under dialogue;
- ambience must not cover dialogue.

Music:
- optional;
- must not become louder than dialogue or key SFX unless explicitly
  approved for a moment.

## Error Conditions

Block final assembly if:
- any listed shot file is missing;
- any shot validation is missing;
- any shot status is not APPROVED;
- dialogue master in metadata differs from S2V source;
- dialogue speed/duration was changed after S2V;
- audio clips or distorts;
- raw and final file names are ambiguous;
- aspect ratio or frame rate differs from project target without
  approval;
- metadata lacks required asset references.

## Quality Checks

Per shot:
- raw video exists;
- final video exists;
- metadata complete;
- validation report present;
- dialogue sync checked for S2V;
- audio levels checked;
- ambience/SFX/music do not cover dialogue;
- no watermark or generator text;
- approval status present.

Final film:
- 22 approved shot final files included;
- order follows timeline manifest;
- transitions match manifest;
- audio continuity checked;
- no accidental black gaps except designed silence/black;
- `07-final/film-final.mp4` produced only after final approval gate.

## DaVinci Fallback Policy

DaVinci Resolve is optional. Use it only for:
- manual color grading;
- manual audio repair;
- fine edit decisions;
- editorial fixes not solved by headless assembly;
- final creative polish after pipeline output review.

Do not treat DaVinci Resolve as a required pipeline dependency. Any
manual DaVinci change must be documented in metadata or validation notes
so the headless pipeline remains understandable.
