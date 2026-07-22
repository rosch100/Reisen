# Apple Signing & Notarization (CI vorbereitet, secrets-gated)

## Wann läuft Signing/Notarize?

Im `release.yml` wird Signing/Notarization **nur** gestartet, wenn folgende Secrets/Env-Variablen gesetzt sind:

- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APP_STORE_CONNECT_API_KEY_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER`

Wenn diese Werte fehlen, erzeugt der Release-Workflow weiterhin ein Artifact (Unsigned Pfad) und der Job bleibt erfolgreich.

## Welche Secrets werden benötigt?

### Developer ID Application Zertifikat

1. Exportiere ein **Developer ID Application** Zertifikat als `.p12`
2. Base64-encode den `.p12` Inhalt:
   - Ergebnis in `APPLE_DEVELOPER_ID_P12_BASE64`
3. Setze das `.p12` Export-Passwort in `APPLE_DEVELOPER_ID_P12_PASSWORD`
4. Setze den Team Identifier in `APPLE_TEAM_ID`

### App Store Connect API Key (.p8) für Notarization

1. Lade den `.p8` Schlüssel herunter (App Store Connect API Key)
2. Base64-encode den `.p8` Inhalt:
   - Ergebnis in `APP_STORE_CONNECT_API_KEY_BASE64`
3. Setze:
   - `APP_STORE_CONNECT_API_KEY_KEY_ID` (aus dem Key-Name / Key-ID)
   - `APP_STORE_CONNECT_API_KEY_ISSUER` (Issuer UUID)

## Befehlspfade (SSOT)

- Signing/Notarize Shell Helper: `Scripts/sign-and-notarize.sh`
- Release Workflow triggert den Helper nur im Signed Pfad

## Validierung / Troubleshooting

- Wenn Keychain Identity nicht gefunden wird, prüfe:
  - ob das importierte Zertifikat wirklich „Developer ID Application“ ist
  - ob die Keychain erfolgreich entsperrt/importiert wurde
- Wenn Notarization fehlschlägt:
  - `notarytool submit --wait` liefert die konkrete Apple-Antwort in den Workflow-Logs

