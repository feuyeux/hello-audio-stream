package logger

import (
	"fmt"
	"time"
)

var verbose bool

func Init(v bool) {
	verbose = v
}

func formatTimestamp() string {
	return time.Now().Format("2006-01-02 15:04:05.000")
}

func Debug(message string) {
	if verbose {
		fmt.Printf("[%s] [debug] %s\n", formatTimestamp(), message)
	}
}

func Info(message string) {
	fmt.Printf("[%s] [info] %s\n", formatTimestamp(), message)
}

func Warn(message string) {
	fmt.Printf("[%s] [warn] %s\n", formatTimestamp(), message)
}

func Error(message string) {
	fmt.Printf("[%s] [error] %s\n", formatTimestamp(), message)
}

func Phase(phase string) {
	fmt.Println()
	fmt.Printf("[%s] [info] === %s ===\n", formatTimestamp(), phase)
}
