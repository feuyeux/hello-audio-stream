package server

import (
	"fmt"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
	"github.com/gorilla/websocket"
)

var connCounter int64

// Handler processes WebSocket frames for one connection.
// It owns the per-connection conn ID and current stream ID.
type Handler struct {
	mgr      *StreamManager
	conn     string // connection ID, e.g. "c-42"
	streamID string // currently active stream for this connection
}

func newHandler(mgr *StreamManager, connID string) *Handler {
	return &Handler{mgr: mgr, conn: connID}
}

// handleText parses a JSON control message and dispatches it.
func (h *Handler) handleText(ws *websocket.Conn, raw []byte) {
	msg, err := parseMessage(raw)
	if err != nil {
		h.sendError(ws, "invalid JSON")
		return
	}
	cmd, err := msg.parseCommand()
	if err != nil {
		h.sendError(ws, err.Error())
		return
	}

	switch {
	case cmd.isStream():
		h.handleStreamCmd(ws, msg, cmd.streamCmd)
	case cmd.isData():
		h.handleDataCmd(ws, msg, cmd.dataCmd)
	case cmd.isQuery():
		h.handleQueryCmd(ws, msg, cmd.queryCmd)
	}
}

// handleBinary writes an incoming binary frame to the active stream.
func (h *Handler) handleBinary(data []byte) {
	if h.streamID == "" {
		logger.Debug("binary data received but no active stream")
		return
	}
	h.mgr.write(h.streamID, data)
}

func (h *Handler) handleStreamCmd(ws *websocket.Conn, msg *Message, cmd StreamCommand) {
	switch cmd {
	case CommandCreate:
		sid := msg.StreamID
		if sid == "" {
			sid = h.conn
		}
		if h.mgr.create(sid) {
			h.streamID = sid
			h.send(ws, msgCreated(sid))
		} else {
			h.sendError(ws, fmt.Sprintf("create failed: %s", sid))
		}

	case CommandComplete:
		if h.streamID == "" {
			h.sendError(ws, "no active stream")
			return
		}
		if h.mgr.complete(h.streamID) {
			h.send(ws, msgCompleted(h.streamID))
		} else {
			h.sendError(ws, "complete failed")
		}

	case CommandClose:
		sid := msg.StreamID
		if sid == "" {
			sid = h.streamID
		}
		if sid == "" {
			h.sendError(ws, "no stream to close")
			return
		}
		h.mgr.delete(sid)
		h.send(ws, msgClosed(sid))
		if sid == h.streamID {
			h.streamID = ""
		}
	}
}

func (h *Handler) handleDataCmd(ws *websocket.Conn, msg *Message, cmd DataCommand) {
	if cmd != CommandRead {
		return
	}
	if msg.Offset == nil || msg.Length == nil {
		h.sendError(ws, "READ requires offset and length")
		return
	}
	sid := msg.StreamID
	if sid == "" {
		sid = h.streamID
	}
	if sid == "" {
		h.sendError(ws, "no stream")
		return
	}
	data := h.mgr.read(sid, *msg.Offset, *msg.Length)
	if len(data) == 0 {
		h.sendError(ws, "no data")
		return
	}
	if err := ws.WriteMessage(websocket.BinaryMessage, data); err != nil {
		logger.Error(fmt.Sprintf("send binary: %v", err))
	}
}

func (h *Handler) handleQueryCmd(ws *websocket.Conn, msg *Message, cmd QueryCommand) {
	switch cmd {
	case CommandGetStatus:
		sid := msg.StreamID
		if sid == "" {
			sid = h.streamID
		}
		if sid == "" {
			h.sendError(ws, "no stream")
			return
		}
		s := h.mgr.get(sid)
		if s == nil {
			h.sendError(ws, "stream not found")
			return
		}
		s.mu.Lock()
		status := string(s.status)
		size := s.offset
		s.mu.Unlock()
		h.send(ws, msgStatus(sid, status, size))

	case CommandListStreams:
		h.send(ws, msgStreamList(h.mgr.list()))
	}
}

func (h *Handler) send(ws *websocket.Conn, msg *Message) {
	data, err := msg.toJSON()
	if err != nil {
		return
	}
	if err := ws.WriteMessage(websocket.TextMessage, data); err != nil {
		logger.Debug(fmt.Sprintf("send text: %v", err))
	}
}

func (h *Handler) sendError(ws *websocket.Conn, text string) {
	h.send(ws, msgError(text))
}

// onClose marks the active stream as ERROR if it was still uploading.
func (h *Handler) onClose() {
	if h.streamID != "" {
		h.mgr.markError(h.streamID)
	}
}
