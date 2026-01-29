using System;
using System.Threading.Tasks;

namespace AudioFileTransfer;

/// <summary>
/// Unified entry point for both server and client modes
/// </summary>
public class Program
{
    public static async Task<int> Main(string[] args)
    {
        // Check if first argument is "server" or "client"
        if (args.Length > 0 && args[0].ToLower() == "server")
        {
            // Remove "server" from args and run server
            var serverArgs = new string[args.Length - 1];
            Array.Copy(args, 1, serverArgs, 0, args.Length - 1);
            await AudioStreamServer.AudioServerApplication.Main(serverArgs);
            return 0;
        }
        else
        {
            // Run client (default behavior)
            // If first arg is "client", remove it
            var clientArgs = args;
            if (args.Length > 0 && args[0].ToLower() == "client")
            {
                clientArgs = new string[args.Length - 1];
                Array.Copy(args, 1, clientArgs, 0, args.Length - 1);
            }
            return await Client.AudioClientApplication.Main(clientArgs);
        }
    }
}
