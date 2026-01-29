using System;

namespace AudioStreamServer;

/// <summary>
/// Simple logger for the audio server (singleton pattern)
/// </summary>
public class Logger
{
    private static Logger? _instance;
    private static readonly object _lock = new object();
    private bool _verbose = false;

    public static Logger Instance
    {
        get
        {
            if (_instance == null)
            {
                lock (_lock)
                {
                    if (_instance == null)
                    {
                        _instance = new Logger();
                    }
                }
            }
            return _instance;
        }
    }

    private Logger()
    {
        // Private constructor for singleton
    }

    public void Init(bool verbose)
    {
        _verbose = verbose;
    }

    private string GetTimestamp()
    {
        return DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
    }

    public void Debug(string message)
    {
        if (_verbose)
        {
            Console.WriteLine($"[{GetTimestamp()}] [debug] {message}");
        }
    }

    public void Info(string message)
    {
        Console.WriteLine($"[{GetTimestamp()}] [info] {message}");
    }

    public void Warning(string message)
    {
        Console.WriteLine($"[{GetTimestamp()}] [warn] {message}");
    }

    public void Error(string message)
    {
        Console.Error.WriteLine($"[{GetTimestamp()}] [error] {message}");
    }
}
