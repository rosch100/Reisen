## Kurzbeschreibung

Worum geht es in diesem PR?

## Checkliste

- [ ] `bash ./Scripts/ci-test.sh` lokal erfolgreich
- [ ] Bei UI-Änderung: `bash ./Scripts/macos-ui-test-remote.sh` (iMac) erfolgreich; lokal nur bei Remote-Ausfall
- [ ] Laufzeitpfade: Diagnostic-Logging (`DiagnosticLogger` / `DiagnosticEvent`) mitgeliefert oder begründet entbehrlich
- [ ] Neue/angepasste Tests treffen die Spec-Semantik (Unit und ggf. XCUI)
- [ ] Keine Scope-Ausweitung ohne Absprache
- [ ] Secrets/Keys werden nicht hinzugefügt (auch nicht in Logs)

