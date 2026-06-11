using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace GyroPlay.Desktop.Services;

public sealed class LoggingService
{
    private const long MaxLogBytes = 256 * 1024;
    private const int MaxLogFiles = 5;
    private readonly List<string> _lines = new();
    private AppPaths _paths = new();
    private string _currentLogFile = string.Empty;

    public event Action<string>? LineAdded;

    public IReadOnlyList<string> Lines => _lines;

    public void Initialize(AppPaths paths)
    {
        _paths = paths;
        Directory.CreateDirectory(_paths.LogDirectory);
        _currentLogFile = Path.Combine(_paths.LogDirectory, $"gyroplay-{DateTime.Now:yyyyMMdd-HHmmss}.log");
        RotateOldLogs();
    }

    public void Write(string message)
    {
        var line = $"[{DateTime.Now:HH:mm:ss}] {Redact(message)}";
        _lines.Add(line);
        if (_lines.Count > 1000)
        {
            _lines.RemoveAt(0);
        }

        Directory.CreateDirectory(_paths.LogDirectory);
        if (File.Exists(_currentLogFile) && new FileInfo(_currentLogFile).Length > MaxLogBytes)
        {
            _currentLogFile = Path.Combine(_paths.LogDirectory, $"gyroplay-{DateTime.Now:yyyyMMdd-HHmmss}.log");
            RotateOldLogs();
        }

        File.AppendAllText(_currentLogFile, line + Environment.NewLine);
        LineAdded?.Invoke(line);
    }

    public void Clear()
    {
        _lines.Clear();
        LineAdded?.Invoke(string.Empty);
    }

    private static string Redact(string value)
    {
        return System.Text.RegularExpressions.Regex.Replace(
            value,
            @"(?i)(pairing[_\s-]*token\W+)([A-F0-9]{6,})",
            "$1[redacted]");
    }

    private void RotateOldLogs()
    {
        var logs = Directory.GetFiles(_paths.LogDirectory, "gyroplay-*.log")
            .Select(path => new FileInfo(path))
            .OrderByDescending(file => file.CreationTimeUtc)
            .Skip(MaxLogFiles);

        foreach (var log in logs)
        {
            try
            {
                log.Delete();
            }
            catch
            {
            }
        }
    }
}
