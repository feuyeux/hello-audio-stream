package main

import (
"flag"
"github.com/feuyeux/hello-mmap/hello-go/src/server"
)

func main() {
port := flag.Int("port", 8080, "server port")
path := flag.String("path", "/audio", "websocket path")
cacheDir := flag.String("cache", "cache", "cache directory")
flag.Parse()
server.Run(*port, *path, *cacheDir)
}
