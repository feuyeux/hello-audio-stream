using System;
using System.Threading.Tasks;
using AudioStreamCache.Client.Core;
using AudioStreamCache.Client.Util;

namespace AudioStreamCache.Client;

/// <summary>
/// Audio client application entry point
/// </summary>
public class AudioClientApplication
{
    public static async Task<int> Main(string[] args)
    {
        try
        {
            // Parse CLI arguments
            var config = CliParser.ParseArgs(args);

            // Initialize logger
            Logger.Init(config.Verbose);

            // Log startup information
            Logger.Info("Audio Stream Cache Client - C# Implementation");
            Logger.Info($"Server URI: {config.ServerUri}");
            Logger.Info($"Input file: {config.InputPath}");
            Logger.Info($"Output file: {config.OutputPath}");

            // Get input file size
            long fileSize = await FileManager.GetFileSizeAsync(config.InputPath);
            Logger.Info($"Input file size: {fileSize} bytes");

            // Initialize performance monitor
            var perf = new PerformanceMonitor(fileSize);

            // Connect to WebSocket server
            Logger.Phase("Connecting to Server");
            using var ws = new WebSocketClient(config.ServerUri);
            await ws.ConnectAsync();
            Logger.Info("Successfully connected to server");

            try
            {
                // Upload file
                Logger.Phase("Starting Upload");
                perf.StartUpload();
                string streamId = await UploadManager.UploadAsync(ws, config.InputPath, fileSize);
                perf.EndUpload();
                Logger.Info($"Upload completed successfully with stream ID: {streamId}");

                // Sleep 2 seconds after upload
                Logger.Info("Upload successful, sleeping for 2 seconds...");
                await Task.Delay(2000);

                // Download file
                Logger.Phase("Starting Download");
                perf.StartDownload();
                await DownloadManager.DownloadAsync(ws, streamId, config.OutputPath, fileSize);
                perf.EndDownload();
                Logger.Info("Download completed successfully");

                // Sleep 2 seconds after download
                Logger.Info("Download successful, sleeping for 2 seconds...");
                await Task.Delay(2000);

                // Verify file integrity
                Logger.Phase("Verifying File Integrity");
                var result = await VerificationModule.VerifyAsync(config.InputPath, config.OutputPath);

                if (result.Passed)
                {
                    Logger.Info("✓ File verification PASSED - Files are identical");
                }
                else
                {
                    Logger.Error("✗ File verification FAILED");
                    if (result.OriginalSize != result.DownloadedSize)
                    {
                        Logger.Error($"  Reason: File size mismatch (expected {result.OriginalSize}, got {result.DownloadedSize})");
                    }
                    if (!string.Equals(result.OriginalChecksum, result.DownloadedChecksum, StringComparison.OrdinalIgnoreCase))
                    {
                        Logger.Error("  Reason: Checksum mismatch");
                    }
                    return 1;
                }

                // Generate performance report
                Logger.Phase("Performance Report");
                var report = perf.GetReport();
                Logger.Info($"Upload Duration: {report.UploadDurationMs} ms");
                Logger.Info($"Upload Throughput: {report.UploadThroughputMbps} Mbps");
                Logger.Info($"Download Duration: {report.DownloadDurationMs} ms");
                Logger.Info($"Download Throughput: {report.DownloadThroughputMbps} Mbps");
                Logger.Info($"Total Duration: {report.TotalDurationMs} ms");
                Logger.Info($"Average Throughput: {report.AverageThroughputMbps} Mbps");

                // Check performance targets
                if (report.UploadThroughputMbps < 100.0 || report.DownloadThroughputMbps < 200.0)
                {
                    Logger.Warn("⚠ Performance targets not met (Upload >100 Mbps, Download >200 Mbps)");
                }

                // Disconnect
                await ws.CloseAsync();
                Logger.Info("Disconnected from server");

                // Log completion
                Logger.Phase("Workflow Complete");
                Logger.Info($"Successfully uploaded, downloaded, and verified file: {config.InputPath}");

                return 0;
            }
            finally
            {
                await ws.CloseAsync();
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Error: {ex.Message}");
            return 1;
        }
    }
}
