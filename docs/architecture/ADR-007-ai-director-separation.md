# ADR-007: AI Director Separation

Status: Proposed

## Context

AI Director adalah arah pengembangan berikutnya untuk membantu planning
dan routing produksi, tetapi belum dibutuhkan untuk fase manual POC.

## Decision Direction

AI Director dipisahkan dari provider dan renderer.

Peran masa depan:

- scene breakdown;
- emotion direction;
- prompt generation;
- audio plan;
- model routing;
- timeline manifest.

## Constraints

- AI Director belum diimplementasikan pada fase sekarang.
- AI Director tidak boleh melewati human approval gates.
- AI Director tidak mengganti source of truth kreatif yang sudah approved.
- Output AI Director harus tetap provider-agnostic sejauh masuk akal.

## Consequences

- Workflow sekarang tetap manual dan human-in-the-loop.
- Otomasi baru dilakukan setelah workflow manual terbukti.
