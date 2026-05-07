using OneMenu.Core.Monitors;

namespace OneMenu.Tests;

public class ActiveWorkTransitionTrackerTests
{
    [Fact]
    public void Update_FirstCall_ReturnsFalse()
    {
        var tracker = new ActiveWorkTransitionTracker();
        var result = tracker.Update(0);
        Assert.False(result);
    }

    [Fact]
    public void Update_ActiveToInactive_ReturnsTrue()
    {
        var tracker = new ActiveWorkTransitionTracker();
        tracker.Update(3); // was active
        var result = tracker.Update(0); // now idle
        Assert.True(result);
    }

    [Fact]
    public void Update_InactiveToInactive_ReturnsFalse()
    {
        var tracker = new ActiveWorkTransitionTracker();
        tracker.Update(0);
        var result = tracker.Update(0);
        Assert.False(result);
    }

    [Fact]
    public void Update_ActiveToActive_ReturnsFalse()
    {
        var tracker = new ActiveWorkTransitionTracker();
        tracker.Update(2);
        var result = tracker.Update(3);
        Assert.False(result);
    }

    [Fact]
    public void Update_TransitionOnlyOnce_ReturnsFalseSecondTime()
    {
        var tracker = new ActiveWorkTransitionTracker();
        tracker.Update(1);
        Assert.True(tracker.Update(0)); // transition detected
        Assert.False(tracker.Update(0)); // still idle, no new transition
    }
}
