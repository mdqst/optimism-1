package main

import (
	"fmt"
	"os"
	"runtime"
	"sync"
)

func main() {
	TestMutex()

	runtime.GC()
	_, _ = os.Stdout.Write([]byte("GC complete!\n"))
}

func TestMutex() {
	m := new(sync.Mutex)

	m.Lock()
	if m.TryLock() {
		_, _ = fmt.Fprintln(os.Stderr, "TryLock succeeded with mutex locked")
		os.Exit(1)
	}
	m.Unlock()
	if !m.TryLock() {
		_, _ = fmt.Fprintln(os.Stderr, "TryLock failed with mutex unlocked")
		os.Exit(1)
	}
	m.Unlock()

	c := make(chan bool)
	for i := 0; i < 10; i++ {
		go HammerMutex(m, 1000, c)
	}
	for i := 0; i < 10; i++ {
		<-c
	}
	fmt.Println("Mutex test passed")
}

func HammerMutex(m *sync.Mutex, loops int, cdone chan bool) {
	for i := 0; i < loops; i++ {
		if i%3 == 0 {
			if m.TryLock() {
				m.Unlock()
			}
			continue
		}
		m.Lock()
		m.Unlock()
	}
	cdone <- true
}
