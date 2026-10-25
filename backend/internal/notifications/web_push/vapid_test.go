package webpush

import (
	lib "github.com/SherClockHolmes/webpush-go"
	"testing"
)

func TestVAPIDRequiresMatchingKeysAndContact(t *testing.T) {
	private, public, err := lib.GenerateVAPIDKeys()
	if err != nil {
		t.Fatal(err)
	}
	if err = ValidateVAPID(public, private, "mailto:operator@example.invalid"); err != nil {
		t.Fatal(err)
	}
	another, _, err := lib.GenerateVAPIDKeys()
	if err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct{ pub, priv, contact string }{{public, another, "mailto:operator@example.invalid"}, {public, private, ""}, {"bad", private, "mailto:operator@example.invalid"}, {public, private, "file:///private"}} {
		if ValidateVAPID(test.pub, test.priv, test.contact) == nil {
			t.Fatal("invalid VAPID configuration accepted")
		}
	}
}
