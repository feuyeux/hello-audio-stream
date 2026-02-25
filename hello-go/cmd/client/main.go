package main

import (
"flag"
"fmt"
"os"
"path/filepath"
"time"

"github.com/feuyeux/hello-mmap/hello-go/src/client"
)

func main() {
input := flag.String("input", "", "input audio file (required)")
srv := flag.String("server", "ws://localhost:8080/audio", "server URI")
output := flag.String("output", "", "output file path")
flag.Parse()

if *input == "" {
fmt.Fprintln(os.Stderr, "usage: --input <file>")
os.Exit(1)
}
if *output == "" {
ts := time.Now().Format("20060102-150405")
*output = fmt.Sprintf("audio/output/out-%s-%s", ts, filepath.Base(*input))
}

client.Run(*srv, *input, *output)
}
