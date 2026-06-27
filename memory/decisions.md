# Decisions

Record long-lived technical decisions here.

## 2026-06-05

- No decisions recorded yet.

## 2026-06-25

- Host the Node backend on the user's own VPS (`103.189.141.67`) under systemd + nginx instead of Render free tier. Reason: Render free slept after 15min inactivity, so the API was effectively "down" for the app. Self-hosting gives persistent uptime. Trade-off: we now own OS/runtime/security upkeep. Process model: systemd `pet-backend` (Restart=always, boot-enabled), nginx reverse proxy on :80, dotenv loads `/opt/pet-backend/.env`.
- HTTPS is now the primary production path via `https://pet.superstar.tots.asia`. Bare-IP HTTP is retained only as a legacy/manual access path and should not be used by app config.

## 2026-06-27

- Use Redis-backed consult state in production (`REDIS_URL=redis://127.0.0.1:6379`) with in-memory fallback for tests and provider/local failures. Reason: the AI consult flow is now stateful and streaming, so state handling must survive beyond one request path.
- Route signup and new pet creation through backend APIs (`/api/v1/auth/register`, `/api/v1/pets`) instead of relying only on direct client Supabase writes. Reason: Supabase email rate limits and RLS edge cases were blocking real app onboarding.
