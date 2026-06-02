using System.Diagnostics;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public record PerformanceMetrics
{
    public double ScanTimeMs { get; init; }
    public double FirstThumbTimeMs { get; init; }
    public int FileCount { get; init; }
    public long MemoryPeakMB { get; init; }
}

public class PerformanceBaselineService
{
    public static PerformanceMetrics MeasureScanAndRender(string folderPath, bool includeSubfolders)
    {
        var memBefore = GC.GetTotalMemory(true);
        var scanSw = Stopwatch.StartNew();

        List<MediaItem> items;
        try
        {
            var scanner = new MediaScannerService();
            items = scanner.QuickScan(folderPath, includeSubfolders);
        }
        catch
        {
            items = new List<MediaItem>();
        }

        scanSw.Stop();
        var scanTimeMs = scanSw.Elapsed.TotalMilliseconds;

        var firstThumbTimeMs = 0.0;
        if (items.Count > 0)
        {
            var thumbSw = Stopwatch.StartNew();
            var thumbService = new ThumbnailService();
            var count = Math.Min(5, items.Count);
            try
            {
                for (var i = 0; i < count; i++)
                {
                    thumbService.GetThumbnail(items[i], 256, 256);
                }
            }
            catch
            {
            }
            thumbSw.Stop();
            firstThumbTimeMs = thumbSw.Elapsed.TotalMilliseconds;
        }

        var memAfter = GC.GetTotalMemory(false);
        var memoryPeakMB = (memAfter - memBefore) / (1024 * 1024);
        if (memoryPeakMB < 0) memoryPeakMB = 0;

        return new PerformanceMetrics
        {
            ScanTimeMs = scanTimeMs,
            FirstThumbTimeMs = firstThumbTimeMs,
            FileCount = items.Count,
            MemoryPeakMB = memoryPeakMB
        };
    }
}
