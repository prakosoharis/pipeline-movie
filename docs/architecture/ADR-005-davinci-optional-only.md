# ADR-005: DaVinci Optional Only

Status: Accepted

## Context

DaVinci Resolve berguna untuk intervensi editorial manual, tetapi project
membutuhkan pipeline utama yang bisa berjalan headless.

## Decision

DaVinci Resolve bukan bagian wajib pipeline.

DaVinci hanya digunakan sebagai fallback untuk:

- koreksi manual;
- fine editing;
- color grading;
- audio repair;
- inspeksi visual.

## Constraints

- Jangan mendokumentasikan DaVinci sebagai requirement utama.
- Hasil manual DaVinci harus dicatat bila mempengaruhi output final.
- Headless assembly tetap menjadi jalur utama.

## Consequences

- Dokumentasi post-production harus memakai istilah media assembly /
  optional editorial.
- DaVinci tidak boleh menjadi blocker untuk POC headless.
