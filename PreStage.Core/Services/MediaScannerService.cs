using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class MediaScannerService
{
    private static readonly HashSet<string> SupportedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".heic", ".heif", ".png", ".tif", ".tiff",
        ".arw", ".cr2", ".cr3", ".dng", ".nef", ".orf", ".raf", ".rw2",
        ".mov", ".mp4", ".m4v"
    };

    private static readonly HashSet<string> ProxyFolderNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "Proxies", "PreStageProxies"
    };

    public List<MediaItem> QuickScan(string folderPath, bool includeSubfolders = false)
    {
        var items = new List<MediaItem>();
        var searchOption = includeSubfolders ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;

        try
        {
            var files = Directory.EnumerateFiles(folderPath, "*.*", searchOption)
                .Where(f => !IsInProxyFolder(f))
                .Where(f => SupportedExtensions.Contains(Path.GetExtension(f)));

            foreach (var file in files)
            {
                try
                {
                    var fileInfo = new FileInfo(file);
                    var mediaType = ClassifyMediaType(file);
                    var item = new MediaItem(
                        file,
                        mediaType,
                        fileInfo.Length,
                        createdDate: fileInfo.CreationTime,
                        modifiedDate: fileInfo.LastWriteTime,
                        lastOpenedDate: fileInfo.LastAccessTime
                    );
                    items.Add(item);
                }
                catch
                {
                }
            }
        }
        catch (DirectoryNotFoundException)
        {
        }

        return items;
    }

    public void EnrichMetadata(List<MediaItem> items, Action<MediaItem> onItemEnriched,
        CancellationToken ct = default)
    {
        var metadataService = new MetadataService();
        foreach (var item in items)
        {
            if (ct.IsCancellationRequested) break;
            metadataService.Enrich(item);
            onItemEnriched(item);
        }
    }

    public List<MediaItem> QuickScanWithPairing(string folderPath, bool includeSubfolders = false)
    {
        var items = QuickScan(folderPath, includeSubfolders);
        var pairingService = new MediaPairingService();
        pairingService.PairRawAndJpeg(items);
        return items;
    }

    private static void EnrichSingleItem(MediaItem item)
    {
        try
        {
            using var stream = File.OpenRead(item.Url);
            using var image = System.Drawing.Image.FromStream(stream, false, false);

            item.PixelWidth = image.Width;
            item.PixelHeight = image.Height;

            if (image.PropertyIdList.Contains(0x0112))
            {
                var orientation = image.GetPropertyItem(0x0112)?.Value?[0] ?? 1;
                item.DisplayRotationDegrees = orientation switch
                {
                    3 or 4 => 180,
                    5 or 6 => 90,
                    7 or 8 => 270,
                    _ => 0
                };
            }

            var (displayW, displayH) = item.DisplayDimensions;
            item.DisplayPixelWidth = displayW;
            item.DisplayPixelHeight = displayH;
        }
        catch
        {
        }
    }

    private static MediaType ClassifyMediaType(string path)
    {
        var ext = Path.GetExtension(path).ToLowerInvariant();
        return ext switch
        {
            ".arw" or ".cr2" or ".cr3" or ".dng" or ".nef" or ".orf" or ".raf" or ".rw2" => MediaType.Raw,
            ".jpg" or ".jpeg" => MediaType.Jpeg,
            ".heic" or ".heif" => MediaType.Heic,
            ".png" => MediaType.Png,
            ".tif" or ".tiff" => MediaType.Tiff,
            ".mov" or ".mp4" or ".m4v" => MediaType.Video,
            _ => MediaType.Unknown
        };
    }

    private static bool IsInProxyFolder(string filePath)
    {
        var dir = Path.GetDirectoryName(filePath);
        while (!string.IsNullOrEmpty(dir))
        {
            var folderName = Path.GetFileName(dir);
            if (ProxyFolderNames.Contains(folderName))
                return true;
            dir = Path.GetDirectoryName(dir);
        }
        return false;
    }
}
