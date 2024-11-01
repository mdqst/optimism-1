package main

import (
	"fmt"
	"os"
	"runtime"
	"sync"
)

func main() {
	TestOnce()
	TestOncePanic()

	fmt.Println("Once test passed")
	runtime.GC()
	_, _ = os.Stdout.Write([]byte("GC complete!\n"))
}

type one int

func (o *one) Increment() {
	*o++
}

func run(once *sync.Once, o *one, c chan bool) {
	once.Do(func() { o.Increment() })
	if v := *o; v != 1 {
		_, _ = fmt.Fprintf(os.Stderr, "once failed inside run: %d is not 1\n", v)
		os.Exit(1)
	}
	c <- true
}

func TestOnce() {
	o := new(one)
	once := new(sync.Once)
	c := make(chan bool)
	const N = 10
	for i := 0; i < N; i++ {
		go run(once, o, c)
	}
	for i := 0; i < N; i++ {
		<-c
	}
	if *o != 1 {
		_, _ = fmt.Fprintf(os.Stderr, "once failed outside run: %d is not 1\n", *o)
		os.Exit(1)
	}
}

func TestOncePanic() {
	var once sync.Once
	func() {
		defer func() {
			if r := recover(); r == nil {
				_, _ = fmt.Fprintf(os.Stderr, "Once.Do did not panic")
				os.Exit(1)
			}
		}()
		once.Do(func() {
			panic("failed")
		})
	}()

	once.Do(func() {
		_, _ = fmt.Fprintf(os.Stderr, "Once.Do called twice")
		os.Exit(1)
	})
}
