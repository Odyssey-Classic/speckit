# preexisting-vuln-only — Go variant

Byte-for-byte the same Go module as `../known-vuln-dep/go/` (same real,
verified `golang.org/x/text@v0.3.5` finding). `go test` (tests),
`gofmt`/`go vet` (quality), and this file (docs) all pass unmodified; the
`security` finding is present but classified pre-existing — see
`../README.md` and `../findings/`.
