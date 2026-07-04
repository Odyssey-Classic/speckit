# known-vuln-dep — Node variant

Minimal Node package depending on `lodash@4.17.15` — a real, published
high-severity Prototype Pollution advisory (`GHSA-p6mc-m468-83gw`) that
`npm audit --audit-level=high` reports (verified locally; exit 1). `npm
test` (tests), `eslint`/`prettier` (quality), and this file (docs) all
pass unmodified; only `security` is affected — see `../README.md` for how
this fixture's outcome is actually asserted (`../findings/`).
