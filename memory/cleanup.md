# Cleanup

Track generated leftovers, large files, stale folders, and delete/archive candidates.

| Date | Path | Reason | Action |
|---|---|---|---|
| 2026-06-05 | TODO | Initial review needed | review |
| 2026-06-27 | `.claude/settings.local.json` | Local agent permissions/history; may contain sensitive command context | keep untracked |
| 2026-06-27 | `petsoul_h5/petsoul-bff/` | Nested Git repository; should be migrated as subtree/submodule or flattened deliberately | review |
| 2026-06-27 | `petsoul_h5/设计参考/` | Large/archived design reference package with PDFs, zip, CRLF/trailing-whitespace files, and nested repo content | review/archive before commit |
| 2026-06-27 | `硬件/*.pdf` | Large local PDF materials; keep out of source commits unless explicitly approved for docs storage | review |
