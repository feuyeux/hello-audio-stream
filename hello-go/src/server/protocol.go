package server

// CommandType classifies a protocol command.
type CommandType int

const (
	CommandTypeStream CommandType = iota
	CommandTypeData
	CommandTypeQuery
)

// StreamCommand is a stream lifecycle command.
type StreamCommand int

const (
	CommandCreate   StreamCommand = iota
	CommandComplete StreamCommand = iota
	CommandClose    StreamCommand = iota
)

// DataCommand is a data-operation command.
type DataCommand int

const (
	CommandRead DataCommand = iota
)

// QueryCommand is a query command.
type QueryCommand int

const (
	CommandGetStatus   QueryCommand = iota
	CommandListStreams QueryCommand = iota
)

// CommandInfo is the result of parsing a command string.
type CommandInfo struct {
	cmdType   CommandType
	streamCmd StreamCommand
	dataCmd   DataCommand
	queryCmd  QueryCommand
}

func (c CommandInfo) isStream() bool { return c.cmdType == CommandTypeStream }
func (c CommandInfo) isData() bool   { return c.cmdType == CommandTypeData }
func (c CommandInfo) isQuery() bool  { return c.cmdType == CommandTypeQuery }
