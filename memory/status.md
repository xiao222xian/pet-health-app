# Status

Status: active
Last reviewed: 2026-06-27
Main AI: mixed
Current goal: maintain the pet health app while organizing the broader pet ecosystem into app, backend, commerce, hardware, and H5 tracks.

## What This Project Is

Pet app and broader pet business workspace with Flutter app, backend, Supabase config, commerce storefront, hardware/robot planning, H5/studio assets, project docs, and memory.

## What Works

- Existing Git repository is connected to GitHub.
- Remote now uses SSH: `git@github.com:xiao222xian/pet-health-app.git`.
- `.gitignore` excludes root `.env` and `backend/.env`.
- `commerce/storefront/` now contains the overseas pet supplement static storefront prototype.
- `PROJECT_STRUCTURE.md` documents current module boundaries.
- Node `backend/` is self-hosted on VPS `103.189.141.67` (Ubuntu 22.04, Node 20): systemd `pet-backend` + nginx HTTPS proxy for `https://pet.superstar.tots.asia`, auto-restart + boot-start. Replaces Render free tier.
- Production health: `https://pet.superstar.tots.asia/health` returns ok. HTTP for `pet.superstar.tots.asia` redirects to HTTPS.
- AI consult is rebuilt as a production-style triage agent with explicit response contract, streaming SSE, rule-based emergency gating, FLU/OpenAI-compatible primary model (`gpt-5.5`), provider fallbacks, and conservative rules fallback.
- Redis is installed/enabled on the VPS and used for consult state when `REDIS_URL=redis://127.0.0.1:6379` is set.
- Backend now provides `POST /api/v1/auth/register` and `POST /api/v1/pets` to avoid client-side Supabase signup/rate-limit/RLS failure paths.
- Local checks are clean: Flutter `analyze`, Flutter tests, iOS simulator debug build, backend build/tests, and backend audit.

## What Is Broken Or Unknown

- Some untracked H5/studio and hardware/material folders need classification before commit.
- Root README still mainly describes the original pet health app and does not fully reflect the broader pet commerce/hardware workspace.

## Active Files Or Modules

- `app/`
- `backend/`
- `commerce/`
- `硬件/`
- `petsoul_h5/`
- `memory/`

## Current Risks

- Root `.env` and `backend/.env` exist locally and must never be committed.
- The nested `petsoul_h5/petsoul-bff/.git` repository needs classification before any broad staging.
- Commerce storefront contains placeholder product, price, ingredient, certification, and checkout details; replace before real launch.
- Pet supplement copy must avoid disease-treatment or drug-like claims.
- Bare-IP HTTP no longer represents the primary production endpoint; use `https://pet.superstar.tots.asia/api/v1`.
- Server uses root login with a password that was shared in chat; rotate it and move to SSH keys. `/opt/pet-backend/.env` on the server holds live secrets (Supabase service role, AI keys).
