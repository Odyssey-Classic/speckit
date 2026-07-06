package fixture

import "testing"

func TestParseAcceptLanguage(t *testing.T) {
	tags, err := ParseAcceptLanguage("en-US")
	if err != nil {
		t.Fatalf("ParseAcceptLanguage returned an error: %v", err)
	}
	if len(tags) != 1 {
		t.Fatalf("ParseAcceptLanguage returned %d tags, want 1", len(tags))
	}
}
