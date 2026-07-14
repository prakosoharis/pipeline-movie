# Generated Video Folder

Folder ini dirancang untuk menyimpan output video per shot setelah POC
atau produksi Wan2.2 dimulai. Saat ini struktur ini adalah dokumentasi
rancangan. Jangan membuat file output palsu.

Rujukan arsitektur:
- `docs/architecture/ADR-002-wan22-self-hosted-video.md`
- `docs/architecture/ADR-006-human-approval-gates.md`

## Tujuan Folder

`05-generated-video/` adalah tempat menyimpan:
- raw video langsung dari Wan2.2 I2V/TI2V/S2V;
- final shot MP4 setelah media assembly;
- metadata produksi per shot;
- validation report per shot.

Hanya shot yang sudah APPROVED boleh masuk final film assembly.

## Raw Video vs Final Shot

Raw video:
- nama file: `shot-XX-video-raw.mp4`;
- output langsung video-generation engine;
- belum tentu memiliki audio final;
- belum tentu memiliki ambience, Foley, SFX, atau music;
- belum boleh masuk final film.

Final shot:
- nama file: `shot-XX-final.mp4`;
- output setelah media assembly;
- dialogue master sudah sinkron bila shot memiliki dialog;
- ambience, Foley, SFX, dan music optional sudah ditambahkan;
- boleh masuk final assembly hanya jika validation status APPROVED.

## Struktur Folder Per Shot

```text
05-generated-video/
└── shot-XX/
    ├── shot-XX-video-raw.mp4
    ├── shot-XX-final.mp4
    ├── shot-XX-metadata.json
    └── shot-XX-validation.md
```

Contoh:

```text
05-generated-video/
└── shot-15/
    ├── shot-15-video-raw.mp4
    ├── shot-15-final.mp4
    ├── shot-15-metadata.json
    └── shot-15-validation.md
```

## Metadata Schema

Contoh schema dokumentasi:

```json
{
  "shot_id": "shot-15",
  "order": 15,
  "model_family": "Wan2.2",
  "model_mode": "S2V",
  "input_image": "02-character/shot-images/shot-15-keyframe.png",
  "dialogue": "04-audio/dialogue/beat-05-untunglah-hanya-mimpi.wav",
  "ambience": "04-audio/ambience/amb-003-bedroom-night.wav",
  "foley": [],
  "sfx": [],
  "music": [],
  "prompt": "03-shots/prompts/shot-15-prompt.txt",
  "seed": null,
  "duration_seconds": 4,
  "raw_video": "05-generated-video/shot-15/shot-15-video-raw.mp4",
  "final_video": "05-generated-video/shot-15/shot-15-final.mp4",
  "approval_status": "PENDING",
  "validation_report": "05-generated-video/shot-15/shot-15-validation.md"
}
```

Required metadata fields:
- `shot_id`;
- `order`;
- `model_family`;
- `model_mode`;
- `input_image`;
- `dialogue`;
- `ambience`;
- `foley`;
- `sfx`;
- `music`;
- `prompt`;
- `seed`;
- `duration_seconds`;
- `raw_video`;
- `final_video`;
- `approval_status`;
- `validation_report`.

## Validation Status

Recommended statuses:
- `PENDING`;
- `REVISE`;
- `REGENERATE`;
- `APPROVED`;
- `REJECTED`.

Rules:
- raw video can be reviewed, but it is not final approval by itself;
- final shot must have `shot-XX-validation.md`;
- only `APPROVED` final shots may be listed in final film manifest;
- rejected or pending shots must not be assembled into
  `07-final/film-final.mp4`.

## Approval Rule

Tidak boleh ada shot yang otomatis masuk final film tanpa status
APPROVED. Approval dapat berasal dari human review, automated checks,
atau kombinasi keduanya, tetapi final gate tetap human approval.
