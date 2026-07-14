# ADR-006: Human Approval Gates

Status: Accepted

## Context

Project memakai asset kreatif dan proses GPU mahal. Human approval
dibutuhkan untuk mencegah drift kreatif dan biaya render yang sia-sia.

## Decision

Approval wajib pada:

- screenplay;
- master character;
- keyframe image;
- dialogue master;
- generated shot;
- final film.

## Constraints

- Tidak ada keyframe yang masuk Wan2.2 tanpa status APPROVED.
- Tidak ada dialogue master yang masuk S2V tanpa APPROVED dan LOCKED.
- Tidak ada shot yang masuk final film assembly tanpa APPROVED.
- Asset REJECTED, CANDIDATE, atau belum ditinjau tidak boleh dipakai
  sebagai input final.

## Consequences

- `08-quality-control/asset-status-report.txt` menjadi catatan status.
- `08-quality-control/image-validation-checklist.txt` dan
  `08-quality-control/video-shot-validation-checklist.txt` wajib dipakai
  pada gate masing-masing.
