namespace AudioStreamCache;

/// <summary>
/// Unified entry point — dispatches to server or client mode.
/// Usage: dotnet run -- server [--port 8080]
///        dotnet run -- client --input FILE [--server URI] [--output FILE]
/// </summary>
public class Program
{
    public static async Task<int> Main(string[] args)
    {
        var mode = args.Length > 0 ? args[0].ToLowerInvariant() : "client";
        var rest = args.Length > 1 ? args[1..] : Array.Empty<string>();

        if (mode == "server")
        {
            await RunServerAsync(rest);
            return 0;
        }
        else
        {
            if (mode == "client") { /* rest already trimmed */ }
            else { rest = args; } // no mode prefix — treat all as client args
            return await RunClientAsync(rest);
        }
    }

    private static async Task RunServerAsync(string[] args)
    {
        int port = 8080;
        string cacheDir = "audio/output";
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "--port" && i + 1 < args.Length)
                int.TryParse(args[++i], out port);
            else if (args[i] == "--cache-dir" && i + 1 < args.Length)
                cacheDir = args[++i];
        }

        var server = new AudioStreamServer.Server(port, cacheDir);
        Console.CancelKeyPress += (_, e) => { e.Cancel = true; server.Stop(); };
        await server.RunAsync();
    }

    private static async Task<int> RunClientAsync(string[] args)
    {
        string? input = null, output = null;
        string serverUri = "ws://localhost:8080";
        string? streamId = null;

        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--input" or "-i":  if (i + 1 < args.Length) input = args[++i]; break;
                case "--output" or "-o": if (i + 1 < args.Length) output = args[++i]; break;
                case "--server" or "-s": if (i + 1 < args.Length) serverUri = args[++i]; break;
                case "--stream-id":      if (i + 1 < args.Length) streamId = args[++i]; break;
            }
        }

        if (string.IsNullOrEmpty(input) || !File.Exists(input))
        {
            Console.Error.WriteLine("Error: --input FILE is required (file must exist)");
            return 1;
        }

        output ??= Path.Combine("audio", "output",
            $"output-{DateTime.Now:yyyyMMdd-HHmmss}-{Path.GetFileName(input)}");
        streamId ??= $"stream-{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";

        var fileSize = new FileInfo(input).Length;
        Console.WriteLine($"Input: {input} ({fileSize} bytes)");

        using var client = new AudioStreamClient.Client(serverUri);
        try
        {
            await client.ConnectAsync();
            await client.UploadAsync(input, streamId);
            await Task.Delay(1000);
            await client.DownloadAsync(streamId, output, fileSize);

            if (AudioStreamClient.Client.Verify(input, output))
            {
                Console.WriteLine("Workflow complete — files match");
                return 0;
            }
            Console.Error.WriteLine("Verification failed");
            return 1;
        }
        finally
        {
            await client.CloseAsync();
        }
    }
}
