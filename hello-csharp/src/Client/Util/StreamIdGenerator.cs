using System;
using System.Text.RegularExpressions;

namespace AudioFileTransfer.Client.Util;

/// <summary>
/// Stream ID generator for creating unique stream identifiers
/// Matches the Java StreamIdGenerator interface.
/// </summary>
public static class StreamIdGenerator
{
    private const string DEFAULT_PREFIX = "stream";

    /// <summary>
    /// Generate a unique stream ID with default prefix "stream".
    /// </summary>
    /// <returns>Stream ID in format "stream-{uuid}"</returns>
    public static string Generate()
    {
        return GenerateWithPrefix(DEFAULT_PREFIX);
    }

    /// <summary>
    /// Generate a unique stream ID with custom prefix.
    /// </summary>
    /// <param name="prefix">Prefix for the stream ID</param>
    /// <returns>Stream ID in format "{prefix}-{uuid}"</returns>
    public static string GenerateWithPrefix(string prefix)
    {
        if (string.IsNullOrEmpty(prefix))
        {
            prefix = DEFAULT_PREFIX;
        }
        
        string uuid = Guid.NewGuid().ToString();
        string streamId = $"{prefix}-{uuid}";
        
        return streamId;
    }

    /// <summary>
    /// Generate a short stream ID (8 characters).
    /// </summary>
    /// <returns>Short stream ID in format "stream-{short-uuid}"</returns>
    public static string GenerateShort()
    {
        return GenerateShortWithPrefix(DEFAULT_PREFIX);
    }

    /// <summary>
    /// Generate a short stream ID with custom prefix.
    /// </summary>
    /// <param name="prefix">Prefix for the stream ID</param>
    /// <returns>Short stream ID in format "{prefix}-{short-uuid}"</returns>
    public static string GenerateShortWithPrefix(string prefix)
    {
        if (string.IsNullOrEmpty(prefix))
        {
            prefix = DEFAULT_PREFIX;
        }
        
        string uuid = Guid.NewGuid().ToString("N").Substring(0, 8);
        string streamId = $"{prefix}-{uuid}";
        
        return streamId;
    }

    /// <summary>
    /// Validate a stream ID format.
    /// </summary>
    /// <param name="streamId">Stream ID to validate</param>
    /// <returns>True if valid format</returns>
    public static bool Validate(string streamId)
    {
        if (string.IsNullOrEmpty(streamId))
        {
            return false;
        }
        
        // Check if it matches the expected pattern
        Regex pattern = new Regex(@"^[a-zA-Z0-9_-]+-[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$");
        return pattern.IsMatch(streamId);
    }

    /// <summary>
    /// Validate a short stream ID format.
    /// </summary>
    /// <param name="streamId">Stream ID to validate</param>
    /// <returns>True if valid short format</returns>
    public static bool ValidateShort(string streamId)
    {
        if (string.IsNullOrEmpty(streamId))
        {
            return false;
        }
        
        // Check if it matches the short pattern: prefix-8chars
        Regex pattern = new Regex(@"^[a-zA-Z0-9_-]+-[a-f0-9]{8}$");
        return pattern.IsMatch(streamId);
    }

    /// <summary>
    /// Extract the prefix from a stream ID.
    /// </summary>
    /// <param name="streamId">Stream ID</param>
    /// <returns>Prefix, or null if invalid format</returns>
    public static string? ExtractPrefix(string streamId)
    {
        if (string.IsNullOrEmpty(streamId))
        {
            return null;
        }
        
        int dashIndex = streamId.IndexOf('-');
        if (dashIndex > 0)
        {
            return streamId.Substring(0, dashIndex);
        }
        
        return null;
    }

    /// <summary>
    /// Extract the UUID part from a stream ID.
    /// </summary>
    /// <param name="streamId">Stream ID</param>
    /// <returns>UUID string, or null if invalid format</returns>
    public static string? ExtractUuid(string streamId)
    {
        if (string.IsNullOrEmpty(streamId))
        {
            return null;
        }
        
        int dashIndex = streamId.IndexOf('-');
        if (dashIndex > 0 && dashIndex < streamId.Length - 1)
        {
            return streamId.Substring(dashIndex + 1);
        }
        
        return null;
    }
}
