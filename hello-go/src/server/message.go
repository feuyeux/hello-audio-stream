package server

import (
	"encoding/json"
	"fmt"
	"strings"
)

// Message is the JSON data transfer object for all control messages.
// Both client→server and server→client use the "command" field.
type Message struct {
	Command  string `json:"command"`
	StreamID string `json:"streamId,omitempty"`
	Offset   *int64 `json:"offset,omitempty"`
	Length   *int   `json:"length,omitempty"`
	Msg      string `json:"message,omitempty"`
	Status   string `json:"status,omitempty"`
	Size     *int64 `json:"size,omitempty"`
	Streams  string `json:"streams,omitempty"`
}

func parseMessage(raw []byte) (*Message, error) {
	var m Message
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, err
	}
	return &m, nil
}

func (m *Message) toJSON() ([]byte, error) {
	return json.Marshal(m)
}

// Factory helpers — server→client responses.
func msgConnected(connID string) *Message {
	return &Message{Command: "CONNECTED", StreamID: connID, Msg: "Connected"}
}

func msgCreated(id string) *Message {
	return &Message{Command: "CREATED", StreamID: id}
}

func msgCompleted(id string) *Message {
	return &Message{Command: "COMPLETED", StreamID: id}
}

func msgClosed(id string) *Message {
	return &Message{Command: "CLOSED", StreamID: id}
}

func msgStatus(id, status string, size int64) *Message {
	return &Message{Command: "STATUS", StreamID: id, Status: status, Size: &size}
}

func msgStreamList(ids []string) *Message {
	return &Message{Command: "STREAM_LIST", Streams: strings.Join(ids, ",")}
}

func msgError(text string) *Message {
	return &Message{Command: "ERROR", Msg: text}
}

// parseCommand maps the command string to a typed CommandInfo.
func (m *Message) parseCommand() (*CommandInfo, error) {
	switch strings.ToUpper(m.Command) {
	case "CREATE":
		return &CommandInfo{cmdType: CommandTypeStream, streamCmd: CommandCreate}, nil
	case "COMPLETE":
		return &CommandInfo{cmdType: CommandTypeStream, streamCmd: CommandComplete}, nil
	case "CLOSE":
		return &CommandInfo{cmdType: CommandTypeStream, streamCmd: CommandClose}, nil
	case "READ":
		return &CommandInfo{cmdType: CommandTypeData, dataCmd: CommandRead}, nil
	case "GET_STATUS":
		return &CommandInfo{cmdType: CommandTypeQuery, queryCmd: CommandGetStatus}, nil
	case "LIST_STREAMS":
		return &CommandInfo{cmdType: CommandTypeQuery, queryCmd: CommandListStreams}, nil
	default:
		return nil, fmt.Errorf("unknown command: %s", m.Command)
	}
}
