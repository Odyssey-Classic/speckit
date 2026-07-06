package fixture

import "testing"

// TestAdd is deliberately wrong (expects 5, Add(2,2) is 4) so the `tests`
// gate category fails - this fixture exists to prove that outcome
// (tests/fixtures/failing-test/README.md).
func TestAdd(t *testing.T) {
	got := Add(2, 2)
	want := 5
	if got != want {
		t.Errorf("Add(2, 2) = %d, want %d", got, want)
	}
}
