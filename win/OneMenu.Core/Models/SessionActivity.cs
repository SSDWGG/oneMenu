namespace OneMenu.Core.Models;

public class SessionActivity
{
    public string FilePath { get; init; } = "";
    public DateTime ModifiedAt { get; init; }
    public string? Title { get; set; }
    public DateTime? LatestEventAt { get; set; }
    public string? LatestEventType { get; set; }
    public DateTime? LastTaskStartedAt { get; set; }
    public DateTime? LastTaskCompletedAt { get; set; }
    public string? LastAnswer { get; set; }
    public bool SawAnyEvent { get; set; }

    public bool IsOpenTask
    {
        get
        {
            if (LastTaskStartedAt.HasValue && LastTaskCompletedAt.HasValue)
                return LastTaskStartedAt > LastTaskCompletedAt;
            if (LastTaskStartedAt.HasValue)
                return true;
            if (LastTaskCompletedAt.HasValue)
                return false;
            return SawAnyEvent;
        }
    }
}
