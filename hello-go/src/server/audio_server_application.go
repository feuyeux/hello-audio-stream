package server

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
	"github.com/feuyeux/hello-mmap/hello-go/src/server/memory"
	"github.com/feuyeux/hello-mmap/hello-go/src/server/network"
)

// Run starts the audio server application
func Run() {
	// Parse command-line arguments
	port := flag.Int("port", 8080, "Server port")
	path := flag.String("path", "/audio", "WebSocket path")
	flag.Parse()

	logger.Info(fmt.Sprintf("Starting Audio Server on port %d with path %s", *port, *path))

	// Get singleton instances
	streamMgr := memory.GetStreamManager("cache")
	memoryPool := memory.GetMemoryPoolManager(65536, 100)

	// Create and start WebSocket server
	wsServer := network.NewAudioWebSocketServer(*port, *path, streamMgr, memoryPool)

	// Handle graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
		<-sigChan
		logger.Info("Shutting down server...")
		os.Exit(0)
	}()

	wsServer.Start()
}
