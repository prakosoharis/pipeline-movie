# AGENTS.md

This repository is an AI-assisted film production repository for the
short film "Mimpi Yang Mengejar".

## Source of Truth

Priority order when documents conflict:
1. latest architecture decision from the current task/prompt;
2. `docs/architecture/`;
3. `README.md`;
4. `AGENTS.md`;
5. `01-project-bible/project-context.txt`;
6. `03-shots/shot-list.txt`;
7. documents under `04-audio/`;
8. older documents.

## Creative Lock

Do not change approved creative content without explicit instruction:
- story;
- screenplay;
- character identity;
- 22-shot order;
- approved images/keyframes;
- creative direction;
- tagline.

Do not delete existing documents or assets.

## Current Architecture

The project uses Hybrid AI Film Production:
- ChatGPT/manual workflow for creative and visual pre-production;
- ElevenLabs for dialogue, ambience, Foley, and SFX;
- optional music provider such as ElevenLabs Music, Suno, or licensed
  library;
- self-hosted Wan2.2 I2V/TI2V for non-dialog video shots;
- self-hosted Wan2.2-S2V for dialogue shots that need lip-sync;
- FFmpeg internal/headless media assembly;
- DaVinci Resolve only as optional fallback.

FFmpeg is internal/headless and does not create lip-sync. Lip-sync comes
from Wan2.2-S2V using the final dialogue master.

Wan2.2 is the current champion. Future model extensibility is documented in
`docs/architecture/ADR-0005-model-adapter-architecture.md` and
`docs/architecture/MODEL-REGISTRY.md`; no adapter or alternate runtime is
implemented yet. Deployment remains manual through:

```text
pipeline/setup-poc.sh
    -> pipeline/run-poc.sh
    -> human approval
    -> pipeline/setup-production-models.sh
    -> pipeline/run-production.sh
       -> pipeline/mix-audio.sh
       -> pipeline/assemble-final.sh
       -> 07-final/film-final.mp4
```

`config/audio-manifest.json` is the source of truth for per-shot ambience,
dialogue/nonverbal, Foley/SFX, and music placement. The production runner
must validate it before inference and must not bypass the audio mix when
creating the canonical final film.

Architecture decisions are recorded in `docs/architecture/`. Keep those
ADRs aligned with `README.md` and `01-project-bible/project-context.txt`.

## Human Approval Requirements

Human approval is required for:
1. screenplay;
2. master character;
3. keyframe image;
4. dialogue master;
5. generated shot;
6. final film.

No keyframe may be sent to Wan2.2 without APPROVED status. No shot may
enter final film assembly without APPROVED status.

## Naming Convention

Per-shot output convention:

```text
05-generated-video/
└── shot-XX/
    ├── shot-XX-video-raw.mp4
    ├── shot-XX-final.mp4
    ├── shot-XX-metadata.json
    └── shot-XX-validation.md
```

Final output convention:

```text
07-final/film-final.mp4
```

## Documentation Rules

Keep documentation consistent with the latest architecture. Do not
claim model capabilities that are not specified. Do not treat DaVinci
Resolve as mandatory. Do not ask users to run FFmpeg manually as the
main workflow.

Do not create backend code, scripts, Dockerfiles, fake outputs, or
pipeline implementation unless explicitly requested.

Do not rename files already referenced by the shot list. If a path must
be clarified, add alias/canonical-path documentation instead of renaming
approved assets.

Every change must be reported in the final summary with files read,
files changed, files created, decisions applied, conflicts found, and
anything intentionally left unchanged.
