# preexisting-vuln-only — Node variant

Byte-for-byte the same Node package as `../known-vuln-dep/node/` (same
real, verified `lodash@4.17.15` finding). `npm test` (tests),
`eslint`/`prettier` (quality), and this file (docs) all pass unmodified;
the `security` finding is present but classified pre-existing — see
`../README.md` and `../findings/`.
