using System.Security.Cryptography;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class CopyService
{
    private readonly object _pauseLock = new();
    private bool _paused;
    private CancellationTokenSource? _cts;

    public CopyProgress Progress { get; } = new();

    public event Action<string>? OnLogMessage;

    public async Task<CopyLogRecord> CopyAsync(
        List<MediaItem> items,
        string targetFolder,
        CopyOrganizationRule rule,
        CopyConflictPolicy conflictPolicy,
        CopyContentMode contentMode,
        CopyVerificationMode verificationMode,
        CancellationToken ct = default,
        string? sourceRoot = null)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var token = _cts.Token;

        Progress.Reset();
        Progress.IsRunning = true;

        var filtered = contentMode == CopyContentMode.RawOnly
            ? items.Where(i => i.MediaType == MediaType.Raw).ToList()
            : items.ToList();

        Progress.TotalCount = filtered.Count;
        Progress.TotalBytes = filtered.Sum(i => i.FileSize);
        Progress.Message = "Starting copy...";

        var log = new CopyLogRecord
        {
            SourcePath = filtered.FirstOrDefault()?.Url,
            DestinationPath = targetFolder,
            Rule = rule,
            TotalItems = filtered.Count,
            TotalBytes = filtered.Sum(i => i.FileSize),
            Entries = []
        };

        var copiedCount = 0;
        var copiedBytes = 0L;

        foreach (var item in filtered)
        {
            token.ThrowIfCancellationRequested();
            await WaitIfPaused(token);

            Progress.CurrentItem = item.Filename;
            Progress.Message = $"Copying {item.Filename}...";

            var destPath = BuildDestinationPath(item, targetFolder, rule, sourceRoot);
            Directory.CreateDirectory(Path.GetDirectoryName(destPath)!);

            var entry = new CopyLogEntry
            {
                Filename = item.Filename,
                Timestamp = DateTime.UtcNow
            };

            try
            {
                if (MediaOrSidecarExists(destPath))
                {
                    switch (conflictPolicy)
                    {
                        case CopyConflictPolicy.SkipExisting:
                            entry.Status = CopyStatus.Skipped;
                            entry.Message = "File already exists, skipped";
                            Log($"Skipped: {item.Filename}");
                            break;
                        case CopyConflictPolicy.Overwrite:
                            RemoveDestinationSidecar(destPath);
                            File.Copy(item.Url, destPath, true);
                            CopySidecarIfNeeded(item.Url, destPath, overwrite: true);
                            entry.Status = CopyStatus.Copied;
                            entry.Message = "Overwritten";
                            break;
                        case CopyConflictPolicy.AutoRename:
                            destPath = GetUniquePath(destPath);
                            File.Copy(item.Url, destPath);
                            CopySidecarIfNeeded(item.Url, destPath, overwrite: false);
                            entry.Status = CopyStatus.Copied;
                            entry.Message = $"Renamed to {Path.GetFileName(destPath)}";
                            break;
                    }
                }
                else
                {
                    File.Copy(item.Url, destPath);
                    CopySidecarIfNeeded(item.Url, destPath, overwrite: false);
                    entry.Status = CopyStatus.Copied;
                    entry.Message = "Copied";
                }

                if (entry.Status == CopyStatus.Copied)
                {
                    await VerifyFileAsync(item, destPath, verificationMode, entry);
                }
            }
            catch (OperationCanceledException)
            {
                entry.Status = CopyStatus.Cancelled;
                entry.Message = "Copy cancelled";
                log.Entries.Add(entry);
                Progress.IsCancelled = true;
                break;
            }
            catch (Exception ex)
            {
                entry.Status = CopyStatus.Failed;
                entry.Message = ex.Message;
                Log($"Failed: {item.Filename} - {ex.Message}");
            }

            if (entry.Status == CopyStatus.Copied || entry.Status == CopyStatus.Verified)
            {
                copiedCount++;
                copiedBytes += item.FileSize;
            }

            log.Entries.Add(entry);
            Progress.CompletedCount = copiedCount;
            Progress.CompletedBytes = copiedBytes;

            await Task.Delay(1, token);
        }

        Progress.IsRunning = false;
        log.FinishedAt = DateTime.UtcNow;

        if (!Progress.IsCancelled)
            Progress.Message = $"Copy complete: {copiedCount} files, {FormatBytes(copiedBytes)}";
        else
            Progress.Message = $"Copy cancelled: {copiedCount} files copied before cancel";

        return log;
    }

    public void Pause()
    {
        lock (_pauseLock) { _paused = true; }
        Progress.IsPaused = true;
        Progress.Message = "Paused";
    }

    public void Resume()
    {
        lock (_pauseLock)
        {
            _paused = false;
            Monitor.PulseAll(_pauseLock);
        }
        Progress.IsPaused = false;
        Progress.Message = "Resuming...";
    }

    public void Cancel()
    {
        _cts?.Cancel();
        Progress.IsCancelled = true;
        Progress.Message = "Cancelling...";
    }

    private async Task WaitIfPaused(CancellationToken ct)
    {
        while (true)
        {
            bool isPaused;
            lock (_pauseLock) { isPaused = _paused; }

            if (!isPaused) return;

            await Task.Run(() =>
            {
                lock (_pauseLock)
                {
                    while (_paused) Monitor.Wait(_pauseLock);
                }
            }, ct);
        }
    }

    private static string BuildDestinationPath(
        MediaItem item,
        string targetFolder,
        CopyOrganizationRule rule,
        string? sourceRoot)
    {
        return rule switch
        {
            CopyOrganizationRule.PreserveStructure => BuildPreservePath(item, targetFolder, sourceRoot),
            CopyOrganizationRule.CameraModel => BuildCameraPath(item, targetFolder),
            CopyOrganizationRule.Rating => BuildRatingPath(item, targetFolder),
            _ => BuildDatePath(item, targetFolder)
        };
    }

    private static string BuildDatePath(MediaItem item, string targetFolder)
    {
        var date = item.CaptureDate ?? item.CreatedDate ?? DateTime.Now;
        var subFolder = date.ToString("yyyy-MM-dd");
        return Path.Combine(targetFolder, subFolder, item.Filename);
    }

    private static string BuildPreservePath(MediaItem item, string targetFolder, string? sourceRoot)
    {
        if (string.IsNullOrEmpty(item.Url) || string.IsNullOrEmpty(targetFolder))
            return Path.Combine(targetFolder, item.Filename);

        var sourceDir = Path.GetDirectoryName(item.Url) ?? "";
        if (!string.IsNullOrWhiteSpace(sourceRoot))
        {
            try
            {
                var rootFullPath = Path.GetFullPath(sourceRoot);
                var sourceDirFullPath = Path.GetFullPath(sourceDir);
                var relative = Path.GetRelativePath(rootFullPath, sourceDirFullPath);
                if (!relative.StartsWith("..", StringComparison.Ordinal) &&
                    !Path.IsPathRooted(relative))
                {
                    return relative == "."
                        ? Path.Combine(targetFolder, item.Filename)
                        : Path.Combine(targetFolder, relative, item.Filename);
                }
            }
            catch
            {
            }
        }

        var folderName = Path.GetFileName(sourceDir);
        return string.IsNullOrWhiteSpace(folderName)
            ? Path.Combine(targetFolder, item.Filename)
            : Path.Combine(targetFolder, folderName, item.Filename);
    }

    private static string BuildCameraPath(MediaItem item, string targetFolder)
    {
        var camera = string.IsNullOrWhiteSpace(item.CameraModel)
            ? "Unknown" : SanitizeFolderName(item.CameraModel);
        var date = item.CaptureDate ?? item.CreatedDate ?? DateTime.Now;
        var subFolder = $"{camera}/{date:yyyy-MM-dd}";
        return Path.Combine(targetFolder, subFolder, item.Filename);
    }

    private static string BuildRatingPath(MediaItem item, string targetFolder)
    {
        var rating = item.Rating > 0 ? $"{item.Rating}_stars" : "Unrated";
        return Path.Combine(targetFolder, rating, item.Filename);
    }

    private static string GetUniquePath(string path)
    {
        var dir = Path.GetDirectoryName(path) ?? "";
        var name = Path.GetFileNameWithoutExtension(path);
        var ext = Path.GetExtension(path);
        var counter = 1;

        string candidate;
        do
        {
            candidate = Path.Combine(dir, $"{name}_{counter}{ext}");
            counter++;
        } while (MediaOrSidecarExists(candidate));

        return candidate;
    }

    private static bool MediaOrSidecarExists(string mediaPath)
    {
        return File.Exists(mediaPath) || File.Exists(XmpService.GetSidecarPath(mediaPath));
    }

    private static void RemoveDestinationSidecar(string mediaPath)
    {
        var sidecarPath = XmpService.GetSidecarPath(mediaPath);
        if (File.Exists(sidecarPath))
            File.Delete(sidecarPath);
    }

    private static void CopySidecarIfNeeded(string sourceMediaPath, string destinationMediaPath, bool overwrite)
    {
        var sourceSidecar = XmpService.GetSidecarPath(sourceMediaPath);
        if (!File.Exists(sourceSidecar))
            return;

        var destinationSidecar = XmpService.GetSidecarPath(destinationMediaPath);
        File.Copy(sourceSidecar, destinationSidecar, overwrite);
    }

    private async Task VerifyFileAsync(MediaItem source, string destPath,
        CopyVerificationMode mode, CopyLogEntry entry)
    {
        var destInfo = new FileInfo(destPath);
        if (!destInfo.Exists)
        {
            entry.Status = CopyStatus.Failed;
            entry.Message = "Destination file not found after copy";
            return;
        }

        if (destInfo.Length != source.FileSize)
        {
            entry.Status = CopyStatus.Failed;
            entry.Message = $"Size mismatch: src={source.FileSize} dst={destInfo.Length}";
            return;
        }

        if (mode == CopyVerificationMode.Sha256)
        {
            var srcHash = await ComputeSha256Async(source.Url);
            var dstHash = await ComputeSha256Async(destPath);

            if (!string.Equals(srcHash, dstHash, StringComparison.OrdinalIgnoreCase))
            {
                entry.Status = CopyStatus.Failed;
                entry.Message = "SHA-256 mismatch";
                return;
            }
        }

        entry.Status = CopyStatus.Verified;
        entry.Message = mode == CopyVerificationMode.Sha256
            ? "Verified (size + SHA-256)" : "Verified (size)";
    }

    private static async Task<string> ComputeSha256Async(string path)
    {
        using var stream = File.OpenRead(path);
        var hash = await SHA256.HashDataAsync(stream);
        return Convert.ToHexStringLower(hash);
    }

    private void Log(string message)
    {
        OnLogMessage?.Invoke(message);
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes < 1024) return $"{bytes} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
        if (bytes < 1024 * 1024 * 1024) return $"{bytes / (1024.0 * 1024):F1} MB";
        return $"{bytes / (1024.0 * 1024 * 1024):F2} GB";
    }

    private static string SanitizeFolderName(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        foreach (var c in invalid) name = name.Replace(c, '_');
        return name.Trim();
    }
}
