package coordinateroster

import "testing"

func TestPreparedSnapshotBecomesStaleImmediatelyOnInvalidation(t *testing.T) {
	lister := &fakeLister{}
	c, _, _ := fixture(t, lister)
	sub, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer sub.Close()
	initial := receive(t, sub)
	if !sub.Current(initial) {
		t.Fatal("fresh state rejected")
	}
	c.Invalidate()
	if sub.Current(initial) {
		t.Fatal("invalidated state remained current")
	}
	if !sub.RequestRefresh() {
		t.Fatal("refresh rejected")
	}
	fresh := receive(t, sub)
	if !sub.Current(fresh) {
		t.Fatal("fresh rechecked state rejected")
	}
	other, err := c.Subscribe(accountB)
	if err != nil {
		t.Fatal(err)
	}
	defer other.Close()
	otherState := receive(t, other)
	if sub.Current(otherState) {
		t.Fatal("another account's state accepted")
	}
	sub.Close()
	if sub.Current(fresh) {
		t.Fatal("closed subscription accepted")
	}
}
