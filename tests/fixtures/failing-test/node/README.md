# failing-test — Node variant

Minimal Node package for the `failing-test` gate fixture. `index.test.js`
asserts `add(2, 2) === 5` (wrong on purpose) so `npm test` (`node --test`)
fails and the `tests` gate category blocks. `eslint`/`prettier` (quality),
`npm audit`/`gitleaks` (security — no dependency declared, so nothing to
flag), and this file (docs) all pass. See `../README.md` for the full
intent.
