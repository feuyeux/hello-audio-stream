package core

import (
	"encoding/json"
	"fmt"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
	"github.com/gorilla/websocket"
)

type WebSocketClient struct {
	conn *websocket.Conn
}

type ControlMessage struct {
	Type     string `json:"type"`
	StreamID string `json:"streamId,omitempty"`
	Offset   *int64 `json:"offset,omitempty"`
	Length   *int   `json:"length,omitempty"`
	Message  string `json:"message,omitempty"`
}

func Connect(uri string) (*WebSocketClient, error) {
	// Configure dialer to disable compression and set larger buffer sizes
	dialer := websocket.Dialer{
		EnableCompression: false,
		WriteBufferSize:   65536,
		ReadBufferSize:    65536,
	}

	conn, _, err := dialer.Dial(uri, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to connect: %w", err)
	}

	return &WebSocketClient{conn: conn}, nil
}

func (c *WebSocketClient) Close() error {
	return c.conn.Close()
}

func (c *WebSocketClient) SendText(message string) error {
	return c.conn.WriteMessage(websocket.TextMessage, []byte(message))
}

func (c *WebSocketClient) SendBinary(data []byte) error {
	return c.conn.WriteMessage(websocket.BinaryMessage, data)
}

func (c *WebSocketClient) ReceiveText() (string, error) {
	msgType, data, err := c.conn.ReadMessage()
	if err != nil {
		return "", fmt.Errorf("failed to receive message: %w", err)
	}
	if msgType != websocket.TextMessage {
		return "", fmt.Errorf("expected text message, got type %d", msgType)
	}
	return string(data), nil
}

func (c *WebSocketClient) ReceiveBinary() ([]byte, error) {
	msgType, data, err := c.conn.ReadMessage()
	if err != nil {
		return nil, fmt.Errorf("failed to receive message: %w", err)
	}
	if msgType == websocket.TextMessage {
		// Log the text message for debugging
		logger.Debug(fmt.Sprintf("Received text message instead of binary: %s", string(data)))
		// This might be an error response, try to parse it
		var msg ControlMessage
		if err := json.Unmarshal(data, &msg); err == nil && msg.Type == "ERROR" {
			return nil, fmt.Errorf("server error: %s", msg.Message)
		}
		return nil, fmt.Errorf("expected binary message, got text: %s", string(data))
	}
	if msgType != websocket.BinaryMessage {
		return nil, fmt.Errorf("expected binary message, got type %d", msgType)
	}
	return data, nil
}

func (c *WebSocketClient) SendControlMessage(msg ControlMessage) error {
	jsonData, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal control message: %w", err)
	}
	logger.Debug(fmt.Sprintf("Sending control message: %s", string(jsonData)))
	return c.SendText(string(jsonData))
}

func (c *WebSocketClient) ReceiveControlMessage() (*ControlMessage, error) {
	text, err := c.ReceiveText()
	if err != nil {
		return nil, err
	}
	logger.Debug(fmt.Sprintf("Received control message: %s", text))

	var msg ControlMessage
	if err := json.Unmarshal([]byte(text), &msg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal control message: %w", err)
	}
	return &msg, nil
}
