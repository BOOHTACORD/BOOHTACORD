package coordinateroster

import "testing"

func TestNewAccountIncarnationUsesNewGeneration(t *testing.T) {
	coordinator, _, _ := fixture(t, &fakeLister{})
	first, err := coordinator.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	initial := receive(t, first)
	sibling, err := coordinator.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	shared := receive(t, sibling)
	if shared.Generation != initial.Generation {
		t.Fatal("simultaneous sessions lost shared generation")
	}
	first.Close()
	sibling.Close()
	next, err := coordinator.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer next.Close()
	renewed := receive(t, next)
	if renewed.Generation == initial.Generation {
		t.Fatal("revision reset reused old generation")
	}
	if next.Current(initial) || !next.Current(renewed) {
		t.Fatal("subscription accepted a state from an earlier incarnation")
	}
}
