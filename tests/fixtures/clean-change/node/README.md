# clean-change — Node variant

Minimal Node package for the `clean-change` gate fixture. `index.test.js`
asserts the true result (`add(2, 2) === 4`), so every category passes:
`npm test` (tests), `eslint`/`prettier` (quality), `npm audit`/`gitleaks`
with no declared dependency (security), and this file (docs). See
`../README.md` for the full intent.
