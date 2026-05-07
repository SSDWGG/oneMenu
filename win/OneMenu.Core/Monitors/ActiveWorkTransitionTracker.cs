namespace OneMenu.Core.Monitors;

/// <summary>
/// Tracks transitions from active work to idle state.
/// Returns true exactly once when active session count drops to 0 from a non-zero value.
/// </summary>
public struct ActiveWorkTransitionTracker
{
    private int? _previousActiveSessionCount;

    public ActiveWorkTransitionTracker() { }

    /// <summary>
    /// Returns true when all work has just finished (active count went from &gt;0 to 0).
    /// </summary>
    public bool Update(int activeSessionCount)
    {
        var didFinishAllWork = _previousActiveSessionCount switch
        {
            not null => _previousActiveSessionCount > 0 && activeSessionCount == 0,
            null => false
        };

        _previousActiveSessionCount = activeSessionCount;
        return didFinishAllWork;
    }
}
