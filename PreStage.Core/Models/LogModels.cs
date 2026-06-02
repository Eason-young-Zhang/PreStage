namespace PreStage.Core.Models;

public sealed class SimilarityGroup
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public List<MediaItem> Items { get; init; } = [];
    public string GroupLabel { get; set; } = "";
    public double? SimilarityScore { get; set; }
}

public sealed class CopyLogRecord
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public DateTime StartedAt { get; init; } = DateTime.UtcNow;
    public DateTime? FinishedAt { get; set; }
    public string? SourcePath { get; set; }
    public string DestinationPath { get; set; } = "";
    public CopyOrganizationRule Rule { get; init; }
    public int TotalItems { get; set; }
    public long TotalBytes { get; set; }
    public List<CopyLogEntry> Entries { get; set; } = [];
    public bool IsFinished => FinishedAt.HasValue;
}

public sealed class CopyLogEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public DateTime Timestamp { get; init; } = DateTime.UtcNow;
    public string Filename { get; init; } = "";
    public CopyStatus Status { get; set; }
    public string Message { get; set; } = "";
}

public sealed class BatchRenameLogRecord
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
    public string? SourcePath { get; set; }
    public int TotalItems { get; init; }
    public List<BatchRenameLogEntry> Entries { get; init; } = [];
}

public sealed class BatchRenameLogEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public string OriginalName { get; init; } = "";
    public string NewName { get; init; } = "";
    public string FolderPath { get; init; } = "";
}
