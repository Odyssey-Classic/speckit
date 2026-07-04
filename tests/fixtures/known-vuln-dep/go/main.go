package fixture

import "golang.org/x/text/language"

// ParseAcceptLanguage wraps golang.org/x/text/language.ParseAcceptLanguage,
// the exact reachable call site that trips GO-2022-1059 and GO-2021-0113 in
// golang.org/x/text@v0.3.5.
func ParseAcceptLanguage(header string) ([]language.Tag, error) {
	tags, _, err := language.ParseAcceptLanguage(header)
	return tags, err
}
