using OneMenu.Core.Monitors;

namespace OneMenu.Tests;

public class ClaudeStatusMonitorTests : IDisposable
{
    private readonly string _tempHome;

    public ClaudeStatusMonitorTests()
    {
        _tempHome = Path.Combine(Path.GetTempPath(), "oneMenuClaudeTest_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(_tempHome, "projects", "test-project"));
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempHome))
            Directory.Delete(_tempHome, true);
    }

    [Fact]
    public void Snapshot_NoDirectory_ReturnsErrorSnapshot()
    {
        var home = Path.Combine(_tempHome, "nonexistent");
        var monitor = new ClaudeStatusMonitor(claudeHome: home);
        var snapshot = monitor.Snapshot();

        Assert.Equal(ClaudeState.Idle, snapshot.State);
        Assert.Equal(0, snapshot.ActiveSessionCount);
        Assert.NotNull(snapshot.ErrorMessage);
    }

    [Fact]
    public void Snapshot_EmptyDirectory_ReturnsIdleSnapshot()
    {
        var monitor = new ClaudeStatusMonitor(claudeHome: _tempHome);
        var snapshot = monitor.Snapshot();

        Assert.Equal(ClaudeState.Idle, snapshot.State);
        Assert.Equal(0, snapshot.ScannedFileCount);
        Assert.Null(snapshot.ErrorMessage);
    }

    [Fact]
    public void Snapshot_WithUserEvent_DetectsActiveTurn()
    {
        var projectDir = Path.Combine(_tempHome, "projects", "test-project");
        var sessionFile = Path.Combine(projectDir, "session.jsonl");

        var now = DateTime.UtcNow;
        var timestamp1 = now.AddMinutes(-5).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");
        var timestamp2 = now.AddMinutes(-3).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");

        File.WriteAllText(sessionFile,
            $$$""""
            {"type":"user","timestamp":"{{{timestamp1}}}","message":{"role":"user","content":"Hello"}}
            {"type":"assistant","timestamp":"{{{timestamp2}}}","message":{"role":"assistant","content":[{"type":"text","text":"Hi there!"}]}}
            """");

        var monitor = new ClaudeStatusMonitor(claudeHome: _tempHome, staleAfter: TimeSpan.FromMinutes(30));
        var snapshot = monitor.Snapshot(now);

        Assert.Equal(ClaudeState.Thinking, snapshot.State);
        Assert.Equal(1, snapshot.ActiveSessionCount);
        Assert.Equal(1, snapshot.ScannedFileCount);
    }

    [Fact]
    public void Snapshot_CompletedTurn_DetectsIdle()
    {
        var projectDir = Path.Combine(_tempHome, "projects", "test-project");
        var sessionFile = Path.Combine(projectDir, "session.jsonl");

        var now = DateTime.UtcNow;
        var timestamp1 = now.AddMinutes(-10).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");
        var timestamp2 = now.AddMinutes(-8).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");

        File.WriteAllText(sessionFile,
            $$$""""
            {"type":"user","timestamp":"{{{timestamp1}}}","message":{"role":"user","content":"Hello"}}
            {"type":"assistant","timestamp":"{{{timestamp2}}}","message":{"role":"assistant","content":[{"type":"text","text":"Hi!"}],"stop_reason":"end_turn"}}
            """");

        var monitor = new ClaudeStatusMonitor(claudeHome: _tempHome, staleAfter: TimeSpan.FromMinutes(30));
        var snapshot = monitor.Snapshot(now);

        Assert.Equal(ClaudeState.Idle, snapshot.State);
    }
}
