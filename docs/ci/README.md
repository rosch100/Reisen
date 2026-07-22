# CI für Reisen

Dieser Ordner dokumentiert die CI/CD-Infrastruktur im Repo.

## Verfügbare Workflows

- `ci.yml`: Build+Test auf PRs und Push auf `master`
- `codeql.yml`: CodeQL (Scheduled + PR)
- `scorecard.yml`: OpenSSF Scorecard
- `release.yml`: Tag-Releases (`v*`) inkl. optionalem Signing/Notarize

## Apple Signing / Notarization

Siehe [`apple-signing.md`](apple-signing.md).

## Branch Protection (Empfehlung)

- Pflicht-Check für Merges: Workflow `CI` aus [`ci.yml`](../../.github/workflows/ci.yml)
- Optional: CodeQL/Scorecard nicht als Pflicht setzen (sie laufen als Security-Workflows und können bei Toolchain-Mismatches temporär fehlschlagen)

