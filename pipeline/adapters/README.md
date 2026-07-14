# Model Adapters

Folder ini dicadangkan untuk adapter model video pada fase pengembangan
berikutnya.

Adapter menjadi batas antara production workflow dan model tertentu. Adapter
nantinya menerjemahkan input generik project menjadi invocation model dan
mengembalikan output dengan kontrak media yang seragam.

## Current State

Belum ada implementasi adapter. Wan2.2 tetap dipanggil oleh pipeline saat ini,
sehingga tidak ada perubahan perilaku production.

Kandidat future meliputi Wan2.2, LTX Video, HunyuanVideo, Open-Sora, dan model
open-source lain yang memenuhi kontrak project. Adapter baru harus melalui ADR,
Golden Benchmark, dan human approval.
