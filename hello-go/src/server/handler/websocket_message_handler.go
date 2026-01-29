package handler

import (
	"encoding/json"
	"fmt"
	"sync"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
	"github.com/feuyeux/hello-mmap/hello-go/src/server/memory"
	"github.com/gorilla/websocket"
)

// WebSocketMessageHandler handles WebSocket message processing
type WebSocketMessageHandler struct {
	streamManager *memory.StreamManager
	memoryPool    *memory.MemoryPoolManager
	clients       map[*websocket.Conn]string
	clientsMutex  *sync.RWMutex
}

// NewWebSocketMessageHandler creates a new message handler
func NewWebSocketMessageHandler(streamMgr *memory.StreamManager, memPool *memory.MemoryPoolManager, clients map[*websocket.Conn]string, mutex *sync.RWMutex) *WebSocketMessageHandler {
	return &WebSocketMessageHandler{
		streamManager: streamMgr,
		memoryPool:    memPool,
		clients:       clients,
		clientsMutex:  mutex,
	}
}

// HandleTextMessage handles text (JSON) messages
func (h *WebSocketMessageHandler) HandleTextMessage(conn *websocket.Conn, message []byte) {
	var data WebSocketMessage
	if err := json.Unmarshal(message, &data); err != nil {
		logger.Debug(fmt.Sprintf("Invalid JSON message: %v", err))
		h.sendError(conn, "Invalid JSON format")
		return
	}

	msgType := data.Type
	if msgType == "" {
		h.sendError(conn, "Missing message type")
		return
	}

	switch msgType {
	case "START":
		h.handleStart(conn, &data)
	case "STOP":
		h.handleStop(conn, &data)
	case "GET":
		h.handleGet(conn, &data)
	default:
		logger.Debug(fmt.Sprintf("Unknown message type: %s", msgType))
		h.sendError(conn, fmt.Sprintf("Unknown message type: %s", msgType))
	}
}

// HandleBinaryMessage handles binary audio data
func (h *WebSocketMessageHandler) HandleBinaryMessage(conn *websocket.Conn, data []byte, streamID string) {
	if streamID == "" {
		logger.Debug("Received binary data but no active stream for client")
		return
	}

	logger.Debug(fmt.Sprintf("Received %d bytes of binary data for stream %s", len(data), streamID))

	// Write to stream
	h.streamManager.WriteChunk(streamID, data)
}

// handleStart handles START message (create new stream)
func (h *WebSocketMessageHandler) handleStart(conn *websocket.Conn, data *WebSocketMessage) {
	streamID := data.StreamId
	if streamID == "" {
		h.sendError(conn, "Missing streamId")
		return
	}

	// Create stream
	if h.streamManager.CreateStream(streamID) {
		// Register this client with the stream
		h.clientsMutex.Lock()
		h.clients[conn] = streamID
		h.clientsMutex.Unlock()

		response := NewStartedMessage(streamID, "Stream started successfully")
		h.sendJSON(conn, response)
		logger.Debug(fmt.Sprintf("Stream started: %s", streamID))
	} else {
		h.sendError(conn, fmt.Sprintf("Failed to create stream: %s", streamID))
	}
}

// handleStop handles STOP message (finalize stream)
func (h *WebSocketMessageHandler) handleStop(conn *websocket.Conn, data *WebSocketMessage) {
	streamID := data.StreamId
	if streamID == "" {
		h.sendError(conn, "Missing streamId")
		return
	}

	// Finalize stream
	if h.streamManager.FinalizeStream(streamID) {
		response := NewStoppedMessage(streamID, "Stream finalized successfully")
		h.sendJSON(conn, response)
		logger.Debug(fmt.Sprintf("Stream finalized: %s", streamID))

		// Unregister stream from client
		h.clientsMutex.Lock()
		h.clients[conn] = ""
		h.clientsMutex.Unlock()
	} else {
		h.sendError(conn, fmt.Sprintf("Failed to finalize stream: %s", streamID))
	}
}

// handleGet handles GET message (read stream data)
func (h *WebSocketMessageHandler) handleGet(conn *websocket.Conn, data *WebSocketMessage) {
	streamID := data.StreamId
	if streamID == "" {
		h.sendError(conn, "Missing streamId")
		return
	}

	offset := int64(0)
	if data.Offset != nil {
		offset = *data.Offset
	}

	length := 65536
	if data.Length != nil {
		length = *data.Length
	}

	// Read data from stream
	chunkData := h.streamManager.ReadChunk(streamID, offset, length)

	if len(chunkData) > 0 {
		// Send binary data
		if err := conn.WriteMessage(websocket.BinaryMessage, chunkData); err != nil {
			logger.Error(fmt.Sprintf("Error sending binary data: %v", err))
		}
		logger.Debug(fmt.Sprintf("Sent %d bytes for stream %s at offset %d", len(chunkData), streamID, offset))
	} else {
		h.sendError(conn, fmt.Sprintf("Failed to read from stream: %s", streamID))
	}
}

// sendJSON sends a JSON message to the client
func (h *WebSocketMessageHandler) sendJSON(conn *websocket.Conn, data *WebSocketMessage) {
	message, err := json.Marshal(data)
	if err != nil {
		logger.Debug(fmt.Sprintf("Error marshaling JSON: %v", err))
		return
	}

	if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
		logger.Debug(fmt.Sprintf("Error sending message: %v", err))
	}
}

// sendError sends an error message to the client
func (h *WebSocketMessageHandler) sendError(conn *websocket.Conn, message string) {
	response := NewErrorMessage(message)
	h.sendJSON(conn, response)
	logger.Debug(fmt.Sprintf("Sent error to client: %s", message))
}
