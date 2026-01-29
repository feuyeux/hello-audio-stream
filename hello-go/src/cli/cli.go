package cli

import (
	"fmt"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"
)

type Config struct {
	Input   string
	Server  string
	Output  string
	Verbose bool
}

var (
	input   string
	server  string
	output  string
	verbose bool
)

func ParseArgs() (*Config, error) {
	rootCmd := &cobra.Command{
		Use:   "audio_stream_client",
		Short: "Audio Stream Cache Client - Go Implementation",
		RunE: func(cmd *cobra.Command, args []string) error {
			return nil
		},
	}

	rootCmd.Flags().StringVar(&input, "input", "", "Input audio file path (required)")
	rootCmd.Flags().StringVar(&server, "server", "ws://localhost:8080/audio", "WebSocket server URI")
	rootCmd.Flags().StringVar(&output, "output", "", "Output file path")
	rootCmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "Enable verbose logging")
	rootCmd.MarkFlagRequired("input")

	if err := rootCmd.Execute(); err != nil {
		return nil, err
	}

	// Generate default output path if not provided
	if output == "" {
		output = generateDefaultOutput(input)
	}

	return &Config{
		Input:   input,
		Server:  server,
		Output:  output,
		Verbose: verbose,
	}, nil
}

func generateDefaultOutput(inputPath string) string {
	filename := filepath.Base(inputPath)
	timestamp := time.Now().Format("20060102-150405")
	return fmt.Sprintf("audio/output/output-%s-%s", timestamp, filename)
}
