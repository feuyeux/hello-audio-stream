using System;

namespace AudioStreamCache;

/// <summary>
/// Simple logger for the audio client
/// </summary>
public static class Logger
{
    private static bool _verbose = false;

    public static void Init(bool verbose)
    {
        _verbose = verbose;
    }

    private static string GetTimestamp()
    {
        return DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
    }

    public static void Debug(string message)
    {
        if (_verbose)
        {
            Console.WriteLine($"[{GetTimestamp()}] [debug] {message}");
        }
    }

    public static void Info(string message)
    {
        Console.WriteLine($"[{GetTimestamp()}] [info] {message}");
    }

    public static void Warn(string message)
    {
        Console.WriteLine($"[{GetTimestamp()}] [warn] {message}");
    }

    public static void Error(string message)
    {
        Console.Error.WriteLine($"[{GetTimestamp()}] [error] {message}");
    }

    public static void Phase(string phaseName)
    {
        Console.WriteLine($"\n=== {phaseName} ===");
    }
}
