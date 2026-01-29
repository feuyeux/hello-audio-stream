using System;
using System.Threading.Tasks;
using AudioStreamServer.Memory;
using AudioStreamServer.Network;

namespace AudioStreamServer;

/// <summary>
/// Audio server application entry point
/// </summary>
public class AudioServerApplication
{
    public static async Task Main(string[] args)
    {
        // Parse command-line arguments
        int port = 8080;
        string path = "/audio";
        
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "--port" && i + 1 < args.Length)
            {
                if (int.TryParse(args[i + 1], out int parsedPort))
                {
                    port = parsedPort;
                }
                i++;
            }
            else if (args[i] == "--path" && i + 1 < args.Length)
            {
                path = args[i + 1];
                i++;
            }
        }

        Console.WriteLine($"Starting Audio Server on port {port} with path {path}");

        // Get singleton instances
        var streamManager = StreamManager.GetInstance("cache");
        var memoryPool = MemoryPoolManager.GetInstance();

        // Create and start WebSocket server
        var server = new AudioWebSocketServer(port, path, streamManager, memoryPool);

        // Handle graceful shutdown
        Console.CancelKeyPress += (sender, e) =>
        {
            Console.WriteLine("Shutting down server...");
            server.Stop();
            Environment.Exit(0);
        };

        // Start server
        await server.Start();
    }
}
