# Pet Project Structure

Last reviewed: 2026-06-17

This project is now a broader pet health and pet commerce workspace. The original iOS pet health app remains the core product, while hardware and commerce tracks are separate long-term business lines.

## Current Top-Level Modules

| Path | Role | Notes |
|---|---|---|
| `app/` | Flutter client | iOS-first pet health app: profiles, logs, timeline, consult, account. |
| `backend/` | Node.js TypeScript API | AI consult and nutrition proxy APIs. Current provider chain is documented in `AGENT.md`. |
| `supabase/` | Database/Auth/Storage | Migrations and local Supabase config. Do not commit local temp state. |
| `commerce/` | Pet ecommerce | Pet supplement storefront and future commerce experiments. First version should stay ecommerce-focused. |
| `硬件/` | Hardware and robot planning | Pet robot docs, cooperation plans, first smart-car execution checklist. |
| `petsoul_h5/` | H5 and related experiments | Existing H5/studio/mock materials. Contains nested repo and generated caches that need classification before broad staging. |
| `docs/` | Product/deployment docs | Deployment, cheap deploy notes, and original product specs/plans. |
| `memory/` | AI project memory | Current status, next steps, changelog, cleanup, and decisions. |
| `shared/` | Shared types | Small shared package area. |

## Boundaries

- `commerce/` is for selling pet products and validating cash flow.
- `app/` is for pet health management and AI consult workflows.
- `硬件/` is for robot/embedded/physical prototype planning.
- `petsoul_h5/` should not be mixed with the main Flutter app or commerce storefront unless intentionally integrated.

## Current Caution

- There is existing uncommitted work across app/backend/H5/hardware. Do not stage broadly.
- Root `.env` and `backend/.env` are local secrets and must not be committed.
- `petsoul_h5/petsoul-bff/` contains a nested Git repository and should be classified before main-repo staging.
- `petsoul_h5/studio/.venv`, `__pycache__`, and other generated caches should stay out of committed source.

## Suggested Future Cleanup

These are non-destructive suggestions; do not move files without a separate review:

1. Keep `commerce/` as the long-term home for ecommerce.
2. Consider renaming `硬件/` to `hardware/` only after confirming all references and user preference.
3. Classify `petsoul_h5/` into H5 prototype, BFF nested repo, studio tooling, and design references.
4. Update root README later to describe the broader pet ecosystem, after current uncommitted app/backend changes are reviewed.
