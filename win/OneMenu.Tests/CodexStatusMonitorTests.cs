using OneMenu.Core.Monitors;

namespace OneMenu.Tests;

public class CodexStatusMonitorTests : IDisposable
{
    private readonly string _tempHome;

    public CodexStatusMonitorTests()
    {
        _tempHome = Path.Combine(Path.GetTempPath(), "oneMenuTest_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(_tempHome, "sessions"));
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempHome))
            Directory.Delete(_tempHome, true);
    }

    [Fact]
    public void Snapshot_NoDirectory_ReturnsErrorSnapshot()
    {
        // Point to a non-existent directory
        var home = Path.Combine(_tempHome, "nonexistent");
        var monitor = new CodexStatusMonitor(codexHome: home);
        var snapshot = monitor.Snapshot();

        Assert.Equal(CodexState.Idle, snapshot.State);
        Assert.Equal(0, snapshot.ActiveSessionCount);
        Assert.NotNull(snapshot.ErrorMessage);
    }

    [Fact]
    public void Snapshot_EmptyDirectory_ReturnsIdleSnapshot()
    {
        var monitor = new CodexStatusMonitor(codexHome: _tempHome);
        var snapshot = monitor.Snapshot();

        Assert.Equal(CodexState.Idle, snapshot.State);
        Assert.Equal(0, snapshot.ScannedFileCount);
        Assert.Null(snapshot.ErrorMessage);
    }

    [Fact]
    public void Snapshot_WithActiveSession_DetectsThinking()
    {
        // Create a mock session file with an active task
        var sessionDir = Path.Combine(_tempHome, "sessions");
        var sessionFile = Path.Combine(sessionDir, $"session-{Guid.NewGuid()}.jsonl");

        var now = DateTime.UtcNow;
        var timestamp1 = now.AddMinutes(-5).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");
        var timestamp2 = now.AddMinutes(-3).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");

        File.WriteAllText(sessionFile,
            $$""""
            {"type":"event_msg","timestamp":"{{timestamp1}}","payload":{"type":"task_started"}}
            {"type":"assistant","timestamp":"{{timestamp2}}","message":{"role":"assistant","content":[{"type":"text","text":"I'm working on this task"}]}}
            """");

        var monitor = new CodexStatusMonitor(codexHome: _tempHome, staleAfter: TimeSpan.FromMinutes(30));
        var snapshot = monitor.Snapshot(now);

        Assert.Equal(CodexState.Thinking, snapshot.State);
        Assert.Equal(1, snapshot.ActiveSessionCount);
        Assert.Equal(1, snapshot.ScannedFileCount);
        Assert.Null(snapshot.ErrorMessage);
    }

    [Fact]
    public void Snapshot_StaleSession_DetectsIdle()
    {
        var sessionDir = Path.Combine(_tempHome, "sessions");
        var sessionFile = Path.Combine(sessionDir, $"session-{Guid.NewGuid()}.jsonl");

        var now = DateTime.UtcNow;
        var oldTimestamp = now.AddMinutes(-60).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");

        File.WriteAllText(sessionFile,
            $$""""
            {"type":"event_msg","timestamp":"{{oldTimestamp}}","payload":{"type":"task_started"}}
            """");

        var monitor = new CodexStatusMonitor(codexHome: _tempHome, staleAfter: TimeSpan.FromMinutes(30));
        var snapshot = monitor.Snapshot(now);

        Assert.Equal(CodexState.Idle, snapshot.State);
    }
}
