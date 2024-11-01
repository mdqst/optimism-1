package main

import (
	"math/rand"
	"runtime"
	"strings"
	"sync"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestConcurrentRange(t *testing.T) {
	const mapSize = 1 << 10

	m := new(sync.Map)
	for n := int64(1); n <= mapSize; n++ {
		m.Store(n, int64(n))
	}

	done := make(chan struct{})
	var wg sync.WaitGroup
	defer func() {
		close(done)
		wg.Wait()
	}()
	for g := int64(runtime.GOMAXPROCS(0)); g > 0; g-- {
		r := rand.New(rand.NewSource(g))
		wg.Add(1)
		go func(g int64) {
			defer wg.Done()
			for i := int64(0); ; i++ {
				select {
				case <-done:
					return
				default:
				}
				for n := int64(1); n < mapSize; n++ {
					if r.Int63n(mapSize) == 0 {
						m.Store(n, n*i*g)
					} else {
						m.Load(n)
					}
				}
			}
		}(g)
	}

	iters := 1 << 10

	for n := iters; n > 0; n-- {
		seen := make(map[int64]bool, mapSize)

		m.Range(func(ki, vi any) bool {
			k, v := ki.(int64), vi.(int64)
			if v%k != 0 {
				t.Fatalf("while Storing multiples of %v, Range saw value %v", k, v)
			}
			if seen[k] {
				t.Fatalf("Range visited key %v twice", k)
			}
			seen[k] = true
			return true
		})

		if len(seen) != mapSize {
			t.Fatalf("Range visited %v elements of %v-element Map", len(seen), mapSize)
		}
	}
}

func TestParseFlag(t *testing.T) {
	cases := []struct {
		name      string
		args      string
		flag      string
		expect    string
		expectErr string
	}{
		{
			name:   "bar=one",
			args:   "--foo --bar=one --baz",
			flag:   "--bar",
			expect: "one",
		},
		{
			name:   "bar one",
			args:   "--foo --bar one --baz",
			flag:   "--bar",
			expect: "one",
		},
		{
			name:   "bar one first flag",
			args:   "--bar one --foo two --baz three",
			flag:   "--bar",
			expect: "one",
		},
		{
			name:   "bar one last flag",
			args:   "--foo --baz --bar one",
			flag:   "--bar",
			expect: "one",
		},
		{
			name:      "non-existent flag",
			args:      "--foo one",
			flag:      "--bar",
			expectErr: "missing flag",
		},
		{
			name:      "empty args",
			args:      "",
			flag:      "--foo",
			expectErr: "missing flag",
		},
	}
	for _, tt := range cases {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			args := strings.Split(tt.args, " ")
			result, err := parseFlag(args, tt.flag)
			if tt.expectErr != "" {
				require.ErrorContains(t, err, tt.expectErr)
			} else {
				require.NoError(t, err)
				require.Equal(t, tt.expect, result)
			}
		})
	}
}
