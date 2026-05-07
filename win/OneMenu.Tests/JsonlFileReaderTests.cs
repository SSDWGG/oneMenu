using OneMenu.Core.Infrastructure;

namespace OneMenu.Tests;

public class JsonlFileReaderTests : IDisposable
{
    private readonly string _tempDir;

    public JsonlFileReaderTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "oneMenuTests_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, true);
    }

    [Fact]
    public void ReadTail_EmptyFile_ReturnsEmpty()
    {
        var filePath = Path.Combine(_tempDir, "empty.jsonl");
        File.WriteAllText(filePath, "");

        var reader = new JsonlFileReader();
        var result = reader.ReadTail(filePath);
        Assert.Equal("", result);
    }

    [Fact]
    public void ReadTail_SmallFile_ReturnsAllContent()
    {
        var filePath = Path.Combine(_tempDir, "small.jsonl");
        var content = "line1\nline2\nline3\n";
        File.WriteAllText(filePath, content);

        var reader = new JsonlFileReader();
        var result = reader.ReadTail(filePath);
        Assert.Equal(content, result);
    }

    [Fact]
    public void ReadTail_LargeFile_ReturnsOnlyTail()
    {
        var filePath = Path.Combine(_tempDir, "large.jsonl");
        var lines = Enumerable.Range(0, 1000).Select(i => new string('x', 100)).ToList();
        File.WriteAllText(filePath, string.Join("\n", lines));

        var reader = new JsonlFileReader(tailByteLimit: 500);
        var result = reader.ReadTail(filePath);
        Assert.True(result.Length <= 600); // roughly within limit
        Assert.False(result.StartsWith("xxxxx")); // partial first line stripped
    }

    [Fact]
    public void ReadTail_StripsPartialFirstLine()
    {
        var filePath = Path.Combine(_tempDir, "partial.jsonl");
        var content = "line1\nline2\nline3\n";
        File.WriteAllText(filePath, content);

        var reader = new JsonlFileReader(tailByteLimit: 12); // "line2\nline3\n" approx
        var result = reader.ReadTail(filePath);
        Assert.False(result.StartsWith("ne1")); // partial line stripped
    }
}
