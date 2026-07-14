# ADR-000: Project Principles

Status: Accepted

## Context

Repository ini menjadi single source of truth untuk project AI-assisted
film production "Mimpi Yang Mengejar". Project masih berada pada fase
manual POC dan human-in-the-loop.

## Decision

Prinsip project:

1. Repository adalah single source of truth.
2. Human approval wajib sebelum proses GPU mahal.
3. Creative assets yang sudah approved tidak boleh berubah diam-diam.
4. Pipeline harus provider-agnostic sejauh masuk akal.
5. Gunakan SaaS untuk pekerjaan ringan dan self-hosting untuk video berat.
6. Pipeline utama harus bisa berjalan headless.
7. Semua output harus reproducible dari prompt, input, metadata, dan model.
8. Cost awareness adalah bagian dari keputusan arsitektur.
9. Jangan menambah tool tanpa manfaat yang jelas.
10. Otomasi dilakukan setelah workflow manual terbukti.

## Consequences

- Dokumentasi harus lebih dulu jelas sebelum implementasi.
- Output final tidak boleh ditandai selesai tanpa file final dan approval.
- Tool baru harus punya alasan produksi yang jelas.
- Metadata dan validation report menjadi bagian wajib dari rancangan output.
