package ratelimit

import (
	"fmt"
	"strings"
	"testing"
)

func TestSourceKeyRepeatedFieldsAggregateBytes(t *testing.T) {
	const client, peer, proxy = "192.0.2.9", "10.0.0.5", "10.0.0.4"
	part := func(first string, size int) string {
		return first + "," + strings.Repeat(" ", size-len(first)-len(proxy)-1) + proxy
	}
	left := part(client, 2048)
	for _, total := range []int{4096, 4097} {
		right := part(proxy, total-len(left)-1)
		fields := []string{left, right}
		if len(left) > 2048 || len(right) > 2048 || len(strings.Join(fields, ",")) != total {
			t.Fatal("invalid aggregate-byte fixture")
		}
		want := client
		if total > 4096 {
			want = peer
		}
		for i, values := range [][]string{fields, {strings.Join(fields, ",")}} {
			t.Run(fmt.Sprintf("bytes%d/form%d", total, i), func(t *testing.T) {
				if got := sourceFromFields(t, peer+":443", values); got != want {
					t.Fatalf("source = %q, want %q", got, want)
				}
			})
		}
	}
}

func TestSourceKeyRepeatedFieldsAggregateHops(t *testing.T) {
	const client, peer, proxy = "192.0.2.9", "10.0.0.5", "10.0.0.4"
	for _, count := range []int{32, 33} {
		individual := make([]string, count)
		individual[0] = client
		for i := 1; i < count; i++ {
			individual[i] = proxy
		}
		two := []string{client, strings.TrimSuffix(strings.Repeat(proxy+",", count-1), ",")}
		want := client
		if count > 32 {
			want = peer
		}
		for layout, fields := range [][]string{individual, two} {
			for form, values := range [][]string{fields, {strings.Join(fields, ",")}} {
				t.Run(fmt.Sprintf("hops%d/layout%d/form%d", count, layout, form), func(t *testing.T) {
					if got := sourceFromFields(t, peer+":443", values); got != want {
						t.Fatalf("source = %q, want %q", got, want)
					}
				})
			}
		}
	}
}
