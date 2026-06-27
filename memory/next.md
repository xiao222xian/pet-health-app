# Next

Last updated: 2026-06-27 10:10 CST

## Exact Next Step

Push the freshly organized commits when ready, then run one manual simulator pass of the rebuilt AI consult UX:

- `hi` should render a guide/follow-up card, not a medical diagnosis card.
- A vague symptom such as `狗狗吐了` should ask for missing information.
- An emergency such as `狗狗误食老鼠药` should render an emergency card and recommend immediate vet care.
- A full symptom description should stream state text, then render a triage report.
- Tap a follow-up question in the AI card; it should fill the input and focus the keyboard.
- Test a new account with no pet profile; the consult input should clearly say to add/select a pet first.
- Create a new pet through the app and confirm it goes through `POST /api/v1/pets`.

The backend has already been deployed and verified online. AI uses FLU first (`https://new.fluapi.com/v1`, `gpt-5.5`) with existing fallback providers and a conservative rules fallback if all model providers fail. Latest live regression confirms guide, follow-up, emergency, triage, and valid SSE behavior.

Project health is now clean for the checked surfaces: Flutter `analyze` has no issues, Flutter tests pass, iOS simulator debug build passes, backend build/tests pass, and backend npm audit reports zero vulnerabilities.

The next production tasks from the previous handoff are complete:

- Production Redis is installed/enabled on the VPS and `REDIS_URL=redis://127.0.0.1:6379` is set in `/opt/pet-backend/.env`.
- `POST /api/v1/pets` exists and live testing confirmed it creates pets for the authenticated user even if a client sends a different `user_id`.
- Consult card widget tests now cover guide/follow-up click, emergency card, and triage sections.

## Commands To Run

```sh
# Backend (self-hosted) health via new HTTPS domain
curl https://pet.superstar.tots.asia/health        # expect {"status":"ok"}

# Run app; config.local.sh and code defaults now point at the HTTPS backend
cd app && ./run.sh

# If building from Xcode, open the workspace, not the project:
open ios/Runner.xcworkspace

# Server-side service / logs if needed
ssh root@103.189.141.67 'systemctl status pet-backend; journalctl -u pet-backend -n 50'
```

## Files To Inspect First

- docs/CHEAP_DEPLOY.md
- app/config.local.sh (gitignored; points API_BASE_URL at https://pet.superstar.tots.asia/api/v1)
- backend/src/index.ts, backend/src/middleware/auth.ts
- backend/src/consult/contract.ts, backend/src/consult/agent.ts, backend/src/consult/intentClassifier.ts, backend/src/consult/riskRules.ts, backend/src/consult/stateStore.ts
- app/lib/features/consult/consult_screen.dart
- /opt/pet-backend on the server (deployed copy + .env)

## Open Questions

- Add persistent conversation-turn storage if product wants cross-device consult continuity beyond the saved final `consult_sessions.ai_response`.
- Consider moving existing pet edit/delete paths behind backend APIs too, so all profile writes consistently bypass client-side RLS edge cases.
- Add rate limiting for auth/register, pet creation, and consult once Redis-backed middleware is introduced.
- Should nginx keep serving the bare-IP pet backend? On 2026-06-26, `http://103.189.141.67/health` and `POST http://103.189.141.67/api/v1/consult` returned nginx 404 because the HTTP default server returns 404; `https://pet.superstar.tots.asia/health` returns 200 and HTTPS proxies correctly to `127.0.0.1:3000`.
- Add a root route (`GET /`) or lightweight landing/diagnostic page if browser visitors should not see Express 404 at `https://pet.superstar.tots.asia/`.
- Migrate `petsoul_h5/petsoul-bff/` (Python/FastAPI, needs MS_TOKEN, was on ModelScope Studio) onto the same VPS too?
- Server hardening: switch to SSH keys, disable root password login, reset the shared root password that was passed in chat.
- Classify remaining unstaged local-only files after commit cleanup (`.claude/settings.local.json`, IDE files, generated caches, nested repo internals, and large materials).

## Completed Plan For This Session

- Inspected worktree and avoided broad staging.
- Updated project memory and stale deployment notes.
- Planned grouped commits for docs/memory, backend consult/auth/pets, Flutter app consult/auth/pet flow, and optional ecosystem prototypes/materials.
- Created grouped commits for safe project changes and left local-only/large/reference assets unstaged.
- Secret/build/dependency exclusions remain mandatory before every staging pass.

## Server Snapshot

- `pet-backend.service`: active/running, enabled, `/usr/bin/node /opt/pet-backend/dist/index.js`, `Restart=always`, `PORT=3000`.
- Listening ports: nginx on 80/443/8080/8081, pet Node on `*:3000`, fintech on `127.0.0.1:3004`, happy on `127.0.0.1:3100`.
- Cert renewal is via `snap.certbot.renew.timer`, not `certbot.timer`; timer is enabled and active.

## Stop Conditions

- Stop before staging `.env`, `backend/.env`, `app/config.local.sh`, nested repository internals, generated caches, dependency folders, or large local media.
- Do not write the server root password into any tracked file or memory.
- Stop before publishing pet supplement claims without supplier-approved labels and compliance review.
