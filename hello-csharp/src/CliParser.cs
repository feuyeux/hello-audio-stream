using System;
using System.IO;

namespace AudioFileTransfer;

/// <summary>
/// Command-line argument parser
/// </summary>
public static class CliParser
{
    public static Config ParseArgs(string[] args)
    {
        string? inputPath = null;
        string? outputPath = null;
        string serverUri = "ws://localhost:8080/audio";
        bool verbose = false;

        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--input":
                    if (i + 1 < args.Length)
                    {
                        inputPath = args[++i];
                    }
                    break;
                case "--output":
                    if (i + 1 < args.Length)
                    {
                        outputPath = args[++i];
                    }
                    break;
                case "--server":
                    if (i + 1 < args.Length)
                    {
                        serverUri = args[++i];
                    }
                    break;
                case "--verbose":
                case "-v":
                    verbose = true;
                    break;
                case "--help":
                case "-h":
                    ShowHelp();
                    Environment.Exit(0);
                    break;
                default:
                    Console.Error.WriteLine($"Unknown argument: {args[i]}");
                    ShowHelp();
                    Environment.Exit(1);
                    break;
            }
        }

        if (string.IsNullOrEmpty(inputPath))
        {
            Console.Error.WriteLine("Error: --input argument is required");
            ShowHelp();
            Environment.Exit(1);
        }

        if (!File.Exists(inputPath))
        {
            Console.Error.WriteLine($"Error: Input file does not exist: {inputPath}");
            Environment.Exit(1);
        }

        if (string.IsNullOrEmpty(outputPath))
        {
            string timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
            string filename = Path.GetFileName(inputPath);
            outputPath = Path.Combine("audio", "output", $"output-{timestamp}-{filename}");
        }

        return new Config
        {
            InputPath = inputPath,
            OutputPath = outputPath,
            ServerUri = serverUri,
            Verbose = verbose
        };
    }

    private static void ShowHelp()
    {
        Console.WriteLine("Audio Stream Cache Client - C# Implementation");
        Console.WriteLine();
        Console.WriteLine("Usage: AudioFileTransfer [options]");
        Console.WriteLine();
        Console.WriteLine("Options:");
        Console.WriteLine("  --input <path>     Input audio file path (required)");
        Console.WriteLine("  --output <path>    Output audio file path (optional)");
        Console.WriteLine("  --server <uri>     WebSocket server URI (default: ws://localhost:8080/audio)");
        Console.WriteLine("  --verbose, -v      Enable verbose logging");
        Console.WriteLine("  --help, -h         Show this help message");
        Console.WriteLine();
        Console.WriteLine("Example:");
        Console.WriteLine("  AudioFileTransfer --input audio/input/test.mp3");
        Console.WriteLine("  AudioFileTransfer --input audio/input/test.mp3 --server ws://192.168.1.100:8080/audio");
        Console.WriteLine("  AudioFileTransfer --input audio/input/test.mp3 --output /tmp/output.mp3 --verbose");
    }
}
