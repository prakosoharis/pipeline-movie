# Architecture Decision Records

Folder ini berisi Architecture Decision Records (ADR) untuk project
"Mimpi Yang Mengejar". ADR adalah source of truth arsitektur produksi
dan harus dibaca bersama `README.md`, `AGENTS.md`, dan
`01-project-bible/project-context.txt`.

## Urutan ADR

| ADR | Status | Topik |
| --- | --- | --- |
| ADR-000 | Accepted | Project principles |
| ADR-001 | Accepted | ChatGPT Images untuk character dan keyframe |
| ADR-002 | Accepted for POC | Wan2.2 self-hosted video |
| ADR-003 | Accepted for POC | Audio tooling |
| ADR-004 | Accepted | Headless FFmpeg assembly |
| ADR-005 | Accepted | DaVinci Resolve optional only |
| ADR-006 | Accepted | Human approval gates |
| ADR-007 | Proposed | AI Director separation |

## Prinsip Pemakaian

- ADR tidak mengubah screenplay, karakter, 22 shot, atau prompt kreatif.
- Jika ADR bertentangan dengan dokumen lama, ADR terbaru dan `README.md`
  terbaru menjadi acuan arsitektur.
- ADR mencatat keputusan, bukan implementasi pipeline.
- Perubahan arsitektur baru harus ditambahkan sebagai ADR baru atau
  revisi eksplisit pada ADR terkait.
