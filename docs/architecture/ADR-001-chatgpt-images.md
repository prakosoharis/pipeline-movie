# ADR-001: ChatGPT Images

Status: Accepted

## Context

Project membutuhkan master character, reference sheet, set/prop, dan
keyframe shot yang konsisten sebelum video generation.

## Decision

ChatGPT Images digunakan untuk:

- master character;
- reference sheet;
- set/prop reference;
- keyframe shot.

## Rationale

- Kualitas visual sudah diterima.
- Editing berbasis reference cukup baik.
- Human validation mudah dilakukan.
- Tidak perlu menambah image model self-hosted pada fase POC.

## Constraints

- Hasil tidak dianggap otomatis konsisten.
- Setiap keyframe tetap harus melalui approval.
- Master face dan reference sheet menjadi sumber identitas.
- Hanya asset berstatus APPROVED yang boleh dikirim ke Wan2.2.

## Consequences

- `02-character/` menjadi source utama visual reference.
- `08-quality-control/image-validation-checklist.txt` tetap wajib sebelum
  video generation.
