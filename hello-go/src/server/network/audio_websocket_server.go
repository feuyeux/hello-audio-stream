package network

import (
	"fmt"
	"net/http"
	"sync"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
	"github.com/feuyeux/hello-mmap/hello-go/src/server/handler"
	"github.com/feuyeux/hello-mmap/hello-go/src/server/memory"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  65536,
	WriteBufferSize: 65536,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

// AudioWebSocketServer handles WebSocket connections for audio streaming
type AudioWebSocketServer struct {
	port           int
	path           string
	clients        map[*websocket.Conn]string // Maps client to stream ID
	clientsMutex   *sync.RWMutex
	messageHandler *handler.WebSocketMessageHandler
}

// NewAudioWebSocketServer creates a new WebSocket server
func NewAudioWebSocketServer(port int, path string, streamMgr *memory.StreamManager, memPool *memory.MemoryPoolManager) *AudioWebSocketServer {
	clients := make(map[*websocket.Conn]string)
	clientsMutex := &sync.RWMutex{}

	return &AudioWebSocketServer{
		port:           port,
		path:           path,
		clients:        clients,
		clientsMutex:   clientsMutex,
		messageHandler: handler.NewWebSocketMessageHandler(streamMgr, memPool, clients, clientsMutex),
	}
}

// Start starts WebSocket server
func (ws *AudioWebSocketServer) Start() {
	http.HandleFunc(ws.path, ws.handleConnection)

	addr := fmt.Sprintf(":%d", ws.port)
	logger.Info(fmt.Sprintf("WebSocket server started on ws://0.0.0.0:%d%s", ws.port, ws.path))

	if err := http.ListenAndServe(addr, nil); err != nil {
		logger.Error(fmt.Sprintf("Failed to start server: %v", err))
	}
}

// handleConnection handles new WebSocket connections
func (ws *AudioWebSocketServer) handleConnection(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to upgrade connection: %v", err))
		return
	}
	defer conn.Close()

	clientAddr := r.RemoteAddr
	logger.Info(fmt.Sprintf("Client connected: %s", clientAddr))

	// Register client
	ws.clientsMutex.Lock()
	ws.clients[conn] = ""
	ws.clientsMutex.Unlock()

	// Handle messages
	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			logger.Debug(fmt.Sprintf("Client disconnected: %s, error: %v", clientAddr, err))
			break
		}

		if messageType == websocket.BinaryMessage {
			ws.clientsMutex.RLock()
			streamID := ws.clients[conn]
			ws.clientsMutex.RUnlock()
			ws.messageHandler.HandleBinaryMessage(conn, message, streamID)
		} else {
			ws.messageHandler.HandleTextMessage(conn, message)
		}
	}

	// Unregister client
	ws.clientsMutex.Lock()
	delete(ws.clients, conn)
	ws.clientsMutex.Unlock()
}
