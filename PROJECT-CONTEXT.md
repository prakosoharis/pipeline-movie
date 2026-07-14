Project Name:
AI Film Production

Mission:
Membangun pipeline AI-native untuk menghasilkan film sinematik berkualitas tinggi dengan biaya serendah mungkin menggunakan kombinasi SaaS dan self-hosted AI.

Vision:
AI Director mengorkestrasi seluruh proses produksi, sementara model-model AI bertindak sebagai spesialis (image, audio, video).

Core Principles:
- Repository is the single source of truth.
- Human approval before expensive GPU rendering.
- Provider-agnostic architecture.
- Cost-aware engineering.
- Reproducible outputs.
- Automation after manual workflow is validated.

Current Technology Decisions:
- Images: ChatGPT Images
- Video: Wan2.2 self-hosted (POC)
- Dialogue/SFX: ElevenLabs (POC)
- Music: Provider agnostic
- Media Assembly: FFmpeg headless
- DaVinci: Optional fallback

Current Phase:
Pre-production selesai dan pipeline deployment manual sudah tersedia.
Audio asset production berjalan.
Wan2.2 POC sudah dijalankan di Vast.ai.

Current Execution Status:
- PyTorch/CUDA/FlashAttention dan Wan2.2 runtime tervalidasi di Vast.ai;
- Shot 15 S2V berhasil dirender dan sudah disetujui secara human;
- checkpoint TI2V production sudah disiapkan setelah approval Shot 15;
- render 22 shot dan satu first-pass audio assembly sudah berhasil diuji
  di Vast.ai;
- hasil first-pass masih memerlukan human review sebelum berstatus final
  APPROVED.

Current Deployment Flow:
  1. `pipeline/setup-poc.sh`
  2. `pipeline/run-poc.sh`
  3. human review dan approval Shot 15
  4. `pipeline/setup-production-models.sh`
  5. `pipeline/run-production.sh`

`pipeline/manifest.json` mendokumentasikan fase deployment. Manifest shot
tetap berada di `config/production-manifest.json`.

Current Champion:
Wan2.2 self-hosted. Model adapter untuk LTX Video, HunyuanVideo,
Open-Sora, dan kandidat lain masih berupa arah arsitektur future.

Audio Assembly Status:
`config/audio-manifest.json` memetakan dialogue/nonverbal, ambience,
Foley/SFX, dan music untuk 22 shot. `pipeline/run-production.sh` sekarang
memvalidasi aset audio sebelum inference, menjalankan mix per shot, lalu
merakit `07-final/film-final.mp4`. Dialogue S2V yang sudah sinkron tetap
menjadi base audio dan FFmpeg tidak membuat lip-sync.
