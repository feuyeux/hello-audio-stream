using System.Threading.Tasks;
using AudioFileTransfer.Client.Core;

namespace AudioFileTransfer.Client.Util;

/// <summary>
/// File verification module for checking file integrity
/// </summary>
public static class VerificationModule
{
    public static async Task<VerificationResult> VerifyAsync(string originalPath, string downloadedPath)
    {
        // Compute checksums
        string originalChecksum = await FileManager.ComputeSha256Async(originalPath);
        string downloadedChecksum = await FileManager.ComputeSha256Async(downloadedPath);

        // Get file sizes
        long originalSize = await FileManager.GetFileSizeAsync(originalPath);
        long downloadedSize = await FileManager.GetFileSizeAsync(downloadedPath);

        // Compare
        bool passed = originalSize == downloadedSize && 
                     string.Equals(originalChecksum, downloadedChecksum, System.StringComparison.OrdinalIgnoreCase);

        return new VerificationResult
        {
            Passed = passed,
            OriginalSize = originalSize,
            DownloadedSize = downloadedSize,
            OriginalChecksum = originalChecksum,
            DownloadedChecksum = downloadedChecksum
        };
    }
}
