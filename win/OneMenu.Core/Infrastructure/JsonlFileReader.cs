using System.Diagnostics;

namespace OneMenu.Core.Infrastructure;

/// <summary>
/// Reads the tail of a file (last N bytes), analogous to the Swift tailByteLimit approach.
/// Strips the partial first line to ensure clean JSONL parsing.
/// </summary>
public class JsonlFileReader
{
    private readonly long _tailByteLimit;

    public JsonlFileReader(long tailByteLimit = 512 * 1024) // 512 KB default
    {
        _tailByteLimit = tailByteLimit;
    }

    /// <summary>
    /// Reads the tail text from a file. Returns only complete lines starting from
    /// within the tail window. Strips the first partial line.
    /// </summary>
    public string ReadTail(string filePath)
    {
        using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        long fileSize = fs.Length;

        if (fileSize == 0)
            return "";

        long bytesToRead = Math.Min(fileSize, _tailByteLimit);
        long offset = fileSize - bytesToRead;
        fs.Seek(offset, SeekOrigin.Begin);

        byte[] buffer = new byte[bytesToRead];
        int bytesRead = fs.Read(buffer, 0, buffer.Length);

        // Handle potential read truncation (should not happen on local files)
        var data = new ReadOnlySpan<byte>(buffer, 0, bytesRead);
        var text = System.Text.Encoding.UTF8.GetString(data);

        // Strip the partial first line if we didn't start at offset 0
        if (offset > 0)
        {
            int firstNewline = text.IndexOf('\n');
            if (firstNewline >= 0)
                text = text[(firstNewline + 1)..];
        }

        return text;
    }
}
