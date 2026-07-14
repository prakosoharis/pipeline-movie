# ADR-0005: Model Adapter Architecture

Status: Proposed

## Context

Wan2.2 adalah current champion untuk production video. Pipeline saat ini
memanggil Wan2.2 secara langsung agar POC dan production tetap sederhana dan
reproducible.

Di fase berikutnya project mungkin membandingkan LTX Video, HunyuanVideo,
Open-Sora, atau model open-source lain. Menanamkan detail setiap model langsung
ke production script akan membuat pergantian provider mahal dan meningkatkan
risiko regresi.

## Decision Direction

Project diarahkan menuju boundary adapter model:

```text
Current:

Production
    |
    v
Wan2.2
```

```text
Future:

Production
    |
    v
Model Adapter
    |-- Wan2.2
    |-- LTX Video
    |-- HunyuanVideo
    |-- Open-Sora
    `-- Future models
```

Production workflow nantinya bergantung pada kontrak input/output generik,
bukan detail command satu provider. Adapter menerjemahkan task, image, audio,
prompt, checkpoint, dan metadata ke format model yang dipilih.

## Why

- production script tidak perlu ditulis ulang untuk setiap model;
- detail command dan dependency tetap berada pada boundary adapter;
- benchmark membandingkan model dengan input shot yang sama;
- model champion dipertahankan sampai kandidat lolos QC;
- human approval tetap menjadi gate sebelum model baru dipakai production.

## Scope Boundary

Keputusan ini belum mengubah pipeline Wan2.2. Tidak ada adapter runtime,
registry executable, routing otomatis, atau migration pada fase sekarang.

Wan2.2 tetap menjadi current champion dan production output harus tetap sama.
