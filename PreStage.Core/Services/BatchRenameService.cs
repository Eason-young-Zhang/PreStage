using PreStage.Core.Models;

namespace PreStage.Core.Services;

public sealed class RenamePreviewEntry
{
    public string OriginalName { get; init; } = "";
    public string NewName { get; init; } = "";
    public string FolderPath { get; init; } = "";
    public string OriginalFullPath { get; init; } = "";
    public string NewFullPath { get; init; } = "";
    public bool HasConflict { get; set; }
}

public sealed class BatchRenameResult
{
    public BatchRenameLogRecord Log { get; init; } = new();
    public List<string> Conflicts { get; init; } = [];
    public bool HasConflicts => Conflicts.Count > 0;
    public string Message { get; set; } = "";
}

public class BatchRenameService
{
    public List<RenamePreviewEntry> Preview(
        List<MediaItem> items,
        string pattern,
        int startIndex = 1)
    {
        var previews = new List<RenamePreviewEntry>();

        for (var i = 0; i < items.Count; i++)
        {
            var item = items[i];
            var folderPath = Path.GetDirectoryName(item.Url) ?? "";
            var ext = Path.GetExtension(item.Filename);
            var newName = ResolvePattern(pattern, item, i + startIndex) + ext;
            var newFullPath = Path.Combine(folderPath, newName);

            previews.Add(new RenamePreviewEntry
            {
                OriginalName = item.Filename,
                NewName = newName,
                FolderPath = folderPath,
                OriginalFullPath = item.Url,
                NewFullPath = newFullPath
            });
        }

        DetectConflicts(previews);

        return previews;
    }

    public BatchRenameResult Apply(
        List<MediaItem> items,
        string pattern,
        int startIndex = 1)
    {
        var preview = Preview(items, pattern, startIndex);

        var conflicts = preview
            .Where(p => p.HasConflict)
            .Select(p => p.NewName)
            .ToList();

        if (conflicts.Count > 0)
        {
            return new BatchRenameResult
            {
                Conflicts = conflicts,
                Message = $"Cannot apply: {conflicts.Count} conflict(s) detected"
            };
        }

        var log = new BatchRenameLogRecord
        {
            SourcePath = items.FirstOrDefault()?.Url,
            TotalItems = items.Count,
            Entries = []
        };

        foreach (var entry in preview)
        {
            try
            {
                File.Move(entry.OriginalFullPath, entry.NewFullPath);

                log.Entries.Add(new BatchRenameLogEntry
                {
                    OriginalName = entry.OriginalName,
                    NewName = entry.NewName,
                    FolderPath = entry.FolderPath
                });
            }
            catch (Exception ex)
            {
                return new BatchRenameResult
                {
                    Conflicts = [$"Failed to rename {entry.OriginalName}: {ex.Message}"],
                    Message = $"Error renaming {entry.OriginalName}: {ex.Message}"
                };
            }
        }

        return new BatchRenameResult
        {
            Log = log,
            Message = $"Renamed {log.Entries.Count} file(s)"
        };
    }

    private static string ResolvePattern(string pattern, MediaItem item, int index)
    {
        var result = pattern;
        result = result.Replace("{date}", FormatDate(item.CaptureDate));
        result = result.Replace("{camera}", FormatCamera(item.CameraModel));
        result = result.Replace("{rating}", item.Rating.ToString());
        result = result.Replace("{index}", index.ToString("D4"));
        result = result.Replace("{original}", Path.GetFileNameWithoutExtension(item.Filename));
        return SanitizeFilename(result);
    }

    private static void DetectConflicts(List<RenamePreviewEntry> previews)
    {
        var targetNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var entry in previews)
        {
            if (!targetNames.Add(entry.NewFullPath))
                entry.HasConflict = true;
        }

        foreach (var entry in previews)
        {
            if (!entry.HasConflict &&
                !string.Equals(entry.OriginalFullPath, entry.NewFullPath, StringComparison.OrdinalIgnoreCase) &&
                File.Exists(entry.NewFullPath))
            {
                entry.HasConflict = true;
            }
        }
    }

    private static string FormatDate(DateTime? date)
    {
        return date?.ToString("yyyy-MM-dd") ?? "NoDate";
    }

    private static string FormatCamera(string? cameraModel)
    {
        if (string.IsNullOrWhiteSpace(cameraModel))
            return "Unknown";
        return SanitizeFilename(cameraModel);
    }

    private static string SanitizeFilename(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        foreach (var c in invalid)
            name = name.Replace(c, '_');
        return name.Trim();
    }
}
