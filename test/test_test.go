package test

import (
	"testing"
)

func TestAdd(t *testing.T) {
	t.Run("test add", func(t *testing.T) {
		r := Add(1, 2)
		if r != 3 {
			t.Errorf("expetcd: %d, but got: %d", 3, r)
		}
	})
}
