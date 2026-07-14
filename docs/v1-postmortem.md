# V1 Postmortem

## Status

Archived baseline.

## Purpose

V1 proved that an AI-film production workflow could run end-to-end, from
creative planning and approved source assets through image, audio, video, and
final-film assembly.

## Production Summary

- Shot count: 22.
- Final-film duration: approximately 1 minute 40 seconds.
- Video model: Wan2.2 self-hosted, using I2V/TI2V for non-dialogue work and
  S2V for dialogue shots where applicable.
- GPU/runtime: Wan2.2 runtime was validated and run on Vast.ai.
- Audio workflow: approved dialogue masters, ambience, Foley/SFX, and music
  were mapped per shot; S2V dialogue remained the base audio where present.
- Final assembly: FFmpeg headless normalized and assembled the selected shot
  media into the final film.
- Cost and elapsed production time: UNKNOWN. V1 did not record these as
  reliable production metrics.

## What Worked

- Production ran end-to-end.
- Self-hosted inference succeeded.
- Shot images, audio, video, and final assembly were produced.
- The workflow demonstrated that a complete film can be produced.

## What Did Not Work

- Video quality remained substantially below the SeaDance comparison
  benchmark.
- Facial acting and motion were not natural enough.
- Batch production was too rigid and linear.
- Revising an individual shot was difficult.
- One candidate per shot was insufficient.
- No candidate approval lifecycle was available.
- Audio and editorial workflows were not yet mature.
- Cost and time were not measured per approved second.

## Main Lessons

- The renderer is not the centre of the production system.
- A film must be managed as shots and candidates.
- Raw output must not automatically become final output.
- Selection, editorial, continuity, sound, and QC are essential production
  concerns.
- SeaDance is a quality benchmark, not a technology blueprint.

## Decision

V1 is frozen. Further development will take place in the
`ai-drama-factory` repository.

## Baseline

Planned tag: `v1.0-baseline`.

The tag has not been created yet and requires explicit approval after the
closure changes are reviewed.
