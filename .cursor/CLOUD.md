# Cloud Agent

User-Rules/Skills: Shared Cloud Environment bzw. `Altanis/cursor` (`Scripts/sync-cloud.sh`).
Doku: https://git.altanis.de/Altanis/cursor — `docs/cloud-agents.md`
Secret: `ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN`
Repo-Overlays: `.cursor/rules/` (u. a. `reisen-*`, `ios-cursor-workflow`, `codereview-exclusions`), `.cursor/skills/*`

**Sync-Hinweis:** Bestehender Clone unter `CURSOR_SSOT_CLONE` wird bei jedem Install mit `git reset --hard origin/${BRANCH}` und `git clean -fd` auf den Remote-Stand gesetzt — lokale Änderungen am SSOT-Clone gehen verloren.
Smoke: `bash .cursor/install-user-ssot.sh --self-test`
