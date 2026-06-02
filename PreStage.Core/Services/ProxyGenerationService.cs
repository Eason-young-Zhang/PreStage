using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public sealed class ProxyGenerationProgress
{
    public string CurrentItem { get; set; } = "";
    public int CompletedCount { get; set; }
    public int TotalCount { get; set; }
    public int SkippedCount { get; set; }
    public int SkippedFresh { get; set; }
    public int FailedCount { get; set; }
    public bool IsRunning { get; set; }
    public bool IsCancelled { get; set; }
    public string Message { get; set; } = "Idle";

    public double Fraction =>
        TotalCount == 0 ? 0 : Math.Min(1.0, (double)(CompletedCount + SkippedCount + SkippedFresh + FailedCount) / TotalCount);
}

public class ProxyGenerationService
{
    private const int MaxLongEdge = 2560;
    private const long JpegQuality = 85L;

    public ProxyGenerationProgress Progress { get; } = new();

    public async Task GenerateProxiesAsync(
        string sourceFolder,
        List<MediaItem> items,
        CancellationToken ct = default)
    {
        Progress.CompletedCount = 0;
        Progress.SkippedCount = 0;
        Progress.SkippedFresh = 0;
        Progress.FailedCount = 0;
        Progress.TotalCount = items.Count;
        Progress.IsRunning = true;
        Progress.IsCancelled = false;
        Progress.Message = "Starting proxy generation...";

        var proxiesFolder = Path.Combine(sourceFolder, "Proxies");
        Directory.CreateDirectory(proxiesFolder);

        foreach (var item in items)
        {
            ct.ThrowIfCancellationRequested();

            Progress.CurrentItem = item.Filename;
            Progress.Message = $"Processing {item.Filename}...";

            var proxyPath = GetProxyPath(proxiesFolder, item);

            if (IsValidProxy(proxyPath) && PreviewImageService.IsFresherThan(item.Url, proxyPath))
            {
                Progress.SkippedFresh++;
                Progress.Message = $"Skipped {item.Filename} (proxy fresh)";
                continue;
            }

            try
            {
                await Task.Run(() => GenerateProxy(item.Url, proxyPath), ct);
                Progress.CompletedCount++;
            }
            catch (OperationCanceledException)
            {
                Progress.IsCancelled = true;
                Progress.Message = "Proxy generation cancelled";
                break;
            }
            catch
            {
                Progress.FailedCount++;
                Progress.Message = $"Failed {item.Filename}";
            }
        }

        Progress.IsRunning = false;

        if (!Progress.IsCancelled)
            Progress.Message = $"Proxy generation complete: {Progress.CompletedCount} created, " +
                $"{Progress.SkippedFresh} fresh, {Progress.FailedCount} failed";
        else
            Progress.Message = $"Proxy generation cancelled: {Progress.CompletedCount} created before cancel";
    }

    public void Cancel()
    {
        Progress.IsCancelled = true;
    }

    private static string GetProxyPath(string proxiesFolder, MediaItem item)
    {
        var nameWithoutExt = Path.GetFileNameWithoutExtension(item.Filename);
        return Path.Combine(proxiesFolder, $"{nameWithoutExt}.jpg");
    }

    private static bool IsValidProxy(string proxyPath)
    {
        if (!File.Exists(proxyPath)) return false;
        try
        {
            var info = new FileInfo(proxyPath);
            if (info.Length == 0) return false;

            using var img = Image.FromFile(proxyPath);
            return img.Width > 0 && img.Height > 0;
        }
        catch
        {
            return false;
        }
    }

    private static void GenerateProxy(string sourcePath, string proxyPath)
    {
        using var sourceImage = Image.FromFile(sourcePath);

        var (newWidth, newHeight) = CalculateDimensions(sourceImage.Width, sourceImage.Height);

        using var bitmap = new Bitmap(newWidth, newHeight);
        using var graphics = Graphics.FromImage(bitmap);

        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
        graphics.SmoothingMode = SmoothingMode.HighQuality;
        graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
        graphics.CompositingQuality = CompositingQuality.HighQuality;
        graphics.DrawImage(sourceImage, 0, 0, newWidth, newHeight);

        var encoderParams = new EncoderParameters(1);
        encoderParams.Param[0] = new EncoderParameter(Encoder.Quality, JpegQuality);

        var jpegCodec = GetJpegCodec();
        if (jpegCodec != null)
            bitmap.Save(proxyPath, jpegCodec, encoderParams);
        else
            bitmap.Save(proxyPath, ImageFormat.Jpeg);
    }

    private static (int Width, int Height) CalculateDimensions(int srcWidth, int srcHeight)
    {
        if (srcWidth <= MaxLongEdge && srcHeight <= MaxLongEdge)
            return (srcWidth, srcHeight);

        var ratio = srcWidth > srcHeight
            ? (double)MaxLongEdge / srcWidth
            : (double)MaxLongEdge / srcHeight;

        return ((int)Math.Round(srcWidth * ratio), (int)Math.Round(srcHeight * ratio));
    }

    private static ImageCodecInfo? GetJpegCodec()
    {
        return ImageCodecInfo.GetImageEncoders()
            .FirstOrDefault(codec => codec.MimeType == "image/jpeg");
    }
}
