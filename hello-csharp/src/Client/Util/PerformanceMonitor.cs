using System;
using System.Diagnostics;

namespace AudioFileTransfer.Client.Util;

/// <summary>
/// Performance monitor for tracking upload and download performance
/// </summary>
public class PerformanceMonitor
{
    private readonly long _fileSize;
    private readonly Stopwatch _uploadStopwatch;
    private readonly Stopwatch _downloadStopwatch;
    private long _uploadDurationMs;
    private long _downloadDurationMs;

    public PerformanceMonitor(long fileSize)
    {
        _fileSize = fileSize;
        _uploadStopwatch = new Stopwatch();
        _downloadStopwatch = new Stopwatch();
    }

    public void StartUpload()
    {
        _uploadStopwatch.Restart();
    }

    public void EndUpload()
    {
        _uploadStopwatch.Stop();
        _uploadDurationMs = _uploadStopwatch.ElapsedMilliseconds;
    }

    public void StartDownload()
    {
        _downloadStopwatch.Restart();
    }

    public void EndDownload()
    {
        _downloadStopwatch.Stop();
        _downloadDurationMs = _downloadStopwatch.ElapsedMilliseconds;
    }

    public PerformanceReport GetReport()
    {
        double uploadThroughput = CalculateThroughput(_fileSize, _uploadDurationMs);
        double downloadThroughput = CalculateThroughput(_fileSize, _downloadDurationMs);
        long totalDuration = _uploadDurationMs + _downloadDurationMs;
        double averageThroughput = CalculateThroughput(_fileSize * 2, totalDuration);

        return new PerformanceReport
        {
            UploadDurationMs = _uploadDurationMs,
            UploadThroughputMbps = uploadThroughput,
            DownloadDurationMs = _downloadDurationMs,
            DownloadThroughputMbps = downloadThroughput,
            TotalDurationMs = totalDuration,
            AverageThroughputMbps = averageThroughput
        };
    }

    private static double CalculateThroughput(long bytes, long milliseconds)
    {
        if (milliseconds == 0) return 0;
        return Math.Round((bytes * 8.0) / (milliseconds * 1_000_000.0), 2);
    }
}
