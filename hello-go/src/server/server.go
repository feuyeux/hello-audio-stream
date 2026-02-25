package server

import (
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  65536,
	WriteBufferSize: 65536,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

var connSeq atomic.Int64

// Server is the WebSocket server for audio streaming.
type Server struct {
	port int
	path string
	mgr  *StreamManager
}

// Run parses flags and starts the server. Blocks until terminated.
func Run(port int, path, cacheDir string) {
	mgr := newStreamManager(cacheDir)
	srv := &Server{port: port, path: path, mgr: mgr}

	// Periodic cleanup
	go func() {
		t := time.NewTicker(30 * time.Second)
		defer t.Stop()
		for range t.C {
			mgr.cleanup()
		}
	}()

	// Graceful shutdown
	go func() {
		ch := make(chan os.Signal, 1)
		signal.Notify(ch, os.Interrupt, syscall.SIGTERM)
		<-ch
		logger.Info("shutting down")
		os.Exit(0)
	}()

	http.HandleFunc(path, srv.accept)
	addr := fmt.Sprintf(":%d", port)
	logger.Info(fmt.Sprintf("server listening on ws://0.0.0.0:%d%s", port, path))
	if err := http.ListenAndServe(addr, nil); err != nil {
		logger.Error(fmt.Sprintf("listen: %v", err))
	}
}

func (s *Server) accept(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.Error(fmt.Sprintf("upgrade: %v", err))
		return
	}
	defer conn.Close()

	connID := fmt.Sprintf("c-%d", connSeq.Add(1))
	logger.Info(fmt.Sprintf("connected: %s", connID))

	h := newHandler(s.mgr, connID)
	// Send CONNECTED immediately after WebSocket handshake
	h.send(conn, msgConnected(connID))

	for {
		mt, data, err := conn.ReadMessage()
		if err != nil {
			logger.Debug(fmt.Sprintf("disconnected: %s: %v", connID, err))
			h.onClose()
			return
		}
		switch mt {
		case websocket.TextMessage:
			h.handleText(conn, data)
		case websocket.BinaryMessage:
			h.handleBinary(data)
		}
	}
}
