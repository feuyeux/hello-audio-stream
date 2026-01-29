package handler

// WebSocketMessage represents a WebSocket control message.
// Used for JSON serialization/deserialization of all control messages.
type WebSocketMessage struct {
	Type     string `json:"type"`
	StreamId string `json:"streamId,omitempty"`
	Offset   *int64 `json:"offset,omitempty"`
	Length   *int   `json:"length,omitempty"`
	Message  string `json:"message,omitempty"`
}

// NewStartedMessage creates a STARTED response message
func NewStartedMessage(streamId, message string) *WebSocketMessage {
	return &WebSocketMessage{
		Type:     "STARTED",
		StreamId: streamId,
		Message:  message,
	}
}

// NewStoppedMessage creates a STOPPED response message
func NewStoppedMessage(streamId, message string) *WebSocketMessage {
	return &WebSocketMessage{
		Type:     "STOPPED",
		StreamId: streamId,
		Message:  message,
	}
}

// NewErrorMessage creates an ERROR response message
func NewErrorMessage(message string) *WebSocketMessage {
	return &WebSocketMessage{
		Type:    "ERROR",
		Message: message,
	}
}
