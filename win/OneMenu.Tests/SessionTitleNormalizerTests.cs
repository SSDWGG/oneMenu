using OneMenu.Core.Infrastructure;
using System.Text.Json;

namespace OneMenu.Tests;

public class SessionTitleNormalizerTests
{
    [Fact]
    public void TitleFrom_SimpleText_ReturnsTrimmedText()
    {
        var result = SessionTitleNormalizer.TitleFrom("Hello World");
        Assert.Equal("Hello World", result);
    }

    [Fact]
    public void TitleFrom_Null_ReturnsNull()
    {
        var result = SessionTitleNormalizer.TitleFrom(null);
        Assert.Null(result);
    }

    [Fact]
    public void TitleFrom_EmptyString_ReturnsNull()
    {
        var result = SessionTitleNormalizer.TitleFrom("");
        Assert.Null(result);
    }

    [Fact]
    public void TitleFrom_WhitespaceOnly_ReturnsNull()
    {
        var result = SessionTitleNormalizer.TitleFrom("   \n  ");
        Assert.Null(result);
    }

    [Fact]
    public void TitleFrom_LongText_TruncatesWithEllipsis()
    {
        var longText = new string('a', 100);
        var result = SessionTitleNormalizer.TitleFrom(longText, maxLength: 50);
        Assert.Equal(50, result!.Length);
        Assert.EndsWith("...", result);
    }

    [Fact]
    public void TitleFrom_FiltersAuxiliaryLines()
    {
        var text = "<ide_speak>\nHello World\n</ide_speak>";
        var result = SessionTitleNormalizer.TitleFrom(text);
        Assert.Equal("Hello World", result);
    }

    [Fact]
    public void TitleFrom_ExtractsAfterRequestMarker()
    {
        var text = "Some prefix\n## My request for Codex:\nPlease implement feature X";
        var result = SessionTitleNormalizer.TitleFrom(text);
        Assert.Equal("Please implement feature X", result);
    }

    [Fact]
    public void TitleFromContent_StringContent_Works()
    {
        var result = SessionTitleNormalizer.TitleFromContent("Test content");
        Assert.Equal("Test content", result);
    }

    [Fact]
    public void ExplicitTitleIn_FindsTitleField()
    {
        using var doc = JsonDocument.Parse("""{"title": "My Session"}""");
        var result = SessionTitleNormalizer.ExplicitTitleIn(doc.RootElement);
        Assert.Equal("My Session", result);
    }

    [Fact]
    public void ExplicitTitleIn_FindsNestedTitle()
    {
        using var doc = JsonDocument.Parse("""{"payload": {"title": "Nested Title"}}""");
        var result = SessionTitleNormalizer.ExplicitTitleIn(doc.RootElement);
        Assert.Equal("Nested Title", result);
    }

    [Fact]
    public void DisplayTitle_ReturnsFallbackForNull()
    {
        var result = SessionTitleNormalizer.DisplayTitle(null);
        Assert.Equal("未命名会话", result);
    }
}
