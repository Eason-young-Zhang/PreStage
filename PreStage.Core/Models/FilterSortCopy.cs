namespace PreStage.Core.Models;

public sealed class FolderNode
{
    public string Name { get; init; } = "";
    public string FullPath { get; init; } = "";
    public bool HasUnloadedChildren { get; init; }
    public List<FolderNode> Children { get; init; } = [];
}

public sealed class FilterState
{
    public int MinimumRating { get; set; }
    public ColorLabel? ColorLabel { get; set; }
    public PickState? PickState { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? CameraModel { get; set; }
    public string? LensModel { get; set; }
    public string SearchText { get; set; } = "";

    public bool Includes(MediaItem item)
    {
        var query = SearchText.Trim();
        if (!string.IsNullOrEmpty(query) &&
            !item.Filename.Contains(query, StringComparison.OrdinalIgnoreCase))
            return false;
        if (item.Rating < MinimumRating) return false;
        if (ColorLabel.HasValue && item.ColorLabel != ColorLabel.Value) return false;
        if (PickState.HasValue && item.PickState != PickState.Value) return false;
        if (StartDate.HasValue && item.CaptureDate < StartDate.Value) return false;
        if (EndDate.HasValue && item.CaptureDate > EndDate.Value) return false;
        if (!string.IsNullOrEmpty(CameraModel) && item.CameraModel != CameraModel) return false;
        if (!string.IsNullOrEmpty(LensModel) && item.LensModel != LensModel) return false;
        return true;
    }
}

public sealed class SortRule
{
    public SortField Field { get; init; }
    public SortDirection Direction { get; init; }

    public SortRule(SortField field = SortField.AddedDate,
        SortDirection direction = SortDirection.Descending)
    {
        Field = field;
        Direction = direction;
    }

    public static SortRule Default => new(SortField.AddedDate, SortDirection.Descending);
}

public sealed class CopyProgress
{
    public string CurrentItem { get; set; } = "";
    public int CompletedCount { get; set; }
    public int TotalCount { get; set; }
    public long CompletedBytes { get; set; }
    public long TotalBytes { get; set; }
    public bool IsRunning { get; set; }
    public bool IsPaused { get; set; }
    public bool IsCancelled { get; set; }
    public string Message { get; set; } = "Idle";

    public double Fraction
    {
        get
        {
            if (TotalBytes > 0)
                return Math.Min(1.0, (double)CompletedBytes / TotalBytes);
            return TotalCount == 0 ? 0 : (double)CompletedCount / TotalCount;
        }
    }

    public void Reset()
    {
        CurrentItem = "";
        CompletedCount = 0;
        TotalCount = 0;
        CompletedBytes = 0;
        TotalBytes = 0;
        IsRunning = false;
        IsPaused = false;
        IsCancelled = false;
        Message = "Idle";
    }
}
