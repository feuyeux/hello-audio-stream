package client

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
	"github.com/gorilla/websocket"
)

const chunkSize = 64 * 1024 // 64KB

// Message is the client-side JSON DTO.
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

// Client wraps a WebSocket connection and provides upload/download.
type Client struct {
	conn *websocket.Conn
}

// Connect dials the server and waits for the CONNECTED handshake.
func Connect(uri string) (*Client, error) {
	dialer := websocket.Dialer{
		EnableCompression: false,
		WriteBufferSize:   chunkSize,
		ReadBufferSize:    chunkSize,
	}
	conn, _, err := dialer.Dial(uri, nil)
	if err != nil {
		return nil, fmt.Errorf("dial %s: %w", uri, err)
	}
	c := &Client{conn: conn}
	// Consume CONNECTED
	msg, err := c.recvText()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("waiting for CONNECTED: %w", err)
	}
	if msg.Command != "CONNECTED" {
		conn.Close()
		return nil, fmt.Errorf("expected CONNECTED, got %s", msg.Command)
	}
	logger.Info(fmt.Sprintf("connected as %s", msg.StreamID))
	return c, nil
}

// Close closes the WebSocket connection.
func (c *Client) Close() { c.conn.Close() }

// Upload reads the file and sends it to the server in 64KB chunks.
// Returns the stream ID used for the upload.
func (c *Client) Upload(filePath, streamID string) error {
	if err := c.sendText(Message{Command: "CREATE", StreamID: streamID}); err != nil {
		return err
	}
	resp, err := c.recvText()
	if err != nil {
		return err
	}
	if resp.Command != "CREATED" {
		return fmt.Errorf("expected CREATED, got %s (msg: %s)", resp.Command, resp.Msg)
	}

	f, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("open %s: %w", filePath, err)
	}
	defer f.Close()

	buf := make([]byte, chunkSize)
	var total int64
	for {
		n, err := f.Read(buf)
		if n > 0 {
			if werr := c.conn.WriteMessage(websocket.BinaryMessage, buf[:n]); werr != nil {
				return fmt.Errorf("send binary: %w", werr)
			}
			total += int64(n)
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("read: %w", err)
		}
	}
	logger.Info(fmt.Sprintf("uploaded %d bytes", total))

	if err := c.sendText(Message{Command: "COMPLETE"}); err != nil {
		return err
	}
	resp, err = c.recvText()
	if err != nil {
		return err
	}
	if resp.Command != "COMPLETED" {
		return fmt.Errorf("expected COMPLETED, got %s", resp.Command)
	}
	return nil
}

// Download fetches the stream in 64KB chunks and writes to outputPath.
func (c *Client) Download(streamID, outputPath string) error {
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		return err
	}
	out, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("create %s: %w", outputPath, err)
	}
	defer out.Close()

	var off int64
	length := chunkSize
	for {
		if err := c.sendText(Message{Command: "READ", StreamID: streamID, Offset: &off, Length: &length}); err != nil {
			return err
		}
		mt, data, err := c.conn.ReadMessage()
		if err != nil {
			return fmt.Errorf("recv: %w", err)
		}
		if mt == websocket.TextMessage {
			var m Message
			_ = json.Unmarshal(data, &m)
			if m.Command == "ERROR" {
				return fmt.Errorf("server error: %s", m.Msg)
			}
			// no more data
			break
		}
		if len(data) == 0 {
			break
		}
		if _, err := out.Write(data); err != nil {
			return fmt.Errorf("write: %w", err)
		}
		off += int64(len(data))
		logger.Debug(fmt.Sprintf("downloaded %d bytes", off))
		if len(data) < chunkSize {
			break
		}
	}
	logger.Info(fmt.Sprintf("download complete: %d bytes", off))
	return nil
}

// Verify computes SHA-256 of both files and returns true if they match.
func Verify(a, b string) (bool, error) {
	ha, err := sha256File(a)
	if err != nil {
		return false, err
	}
	hb, err := sha256File(b)
	if err != nil {
		return false, err
	}
	logger.Info(fmt.Sprintf("input  SHA-256: %s", ha))
	logger.Info(fmt.Sprintf("output SHA-256: %s", hb))
	return strings.EqualFold(ha, hb), nil
}

func sha256File(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func (c *Client) sendText(msg Message) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	return c.conn.WriteMessage(websocket.TextMessage, data)
}

func (c *Client) recvText() (*Message, error) {
	mt, data, err := c.conn.ReadMessage()
	if err != nil {
		return nil, err
	}
	if mt != websocket.TextMessage {
		return nil, fmt.Errorf("expected text message")
	}
	var m Message
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return &m, nil
}

// Run is the entry point called from cmd/client/main.go.
func Run(serverURI, inputPath, outputPath string) {
	c, err := Connect(serverURI)
	if err != nil {
		logger.Error(fmt.Sprintf("connect: %v", err))
		os.Exit(1)
	}
	defer c.Close()

	streamID := fmt.Sprintf("s-%d", time.Now().UnixMilli())

	logger.Info("=== Upload ===")
	if err := c.Upload(inputPath, streamID); err != nil {
		logger.Error(fmt.Sprintf("upload: %v", err))
		os.Exit(1)
	}

	logger.Info("=== Download ===")
	if err := c.Download(streamID, outputPath); err != nil {
		logger.Error(fmt.Sprintf("download: %v", err))
		os.Exit(1)
	}

	logger.Info("=== Verify ===")
	ok, err := Verify(inputPath, outputPath)
	if err != nil {
		logger.Error(fmt.Sprintf("verify: %v", err))
		os.Exit(1)
	}
	if ok {
		logger.Info("SUCCESS")
	} else {
		logger.Error("FAILED: checksum mismatch")
		os.Exit(1)
	}
}
