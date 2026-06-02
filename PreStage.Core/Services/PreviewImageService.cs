using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PreStage.Core.Imaging;
using PixelFormat = System.Drawing.Imaging.PixelFormat;

namespace PreStage.Core.Services;

public class PreviewImageService
{
    public record PreviewResult(
        BitmapSource Bitmap,
        int PixelWidth,
        int PixelHeight,
        double AspectRatio,
        bool IsDirectDecode);

    public PreviewResult? LoadPreview(string filePath, int maxWidth, int maxHeight)
    {
        var proxyPath = GetProxyFilePath(filePath);
        if (proxyPath != null)
            filePath = proxyPath;

        return LoadPreviewDirect(filePath, maxWidth, maxHeight);
    }

    public string? GetProxyFilePath(string filePath)
    {
        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        var isRaw = ext is ".arw" or ".cr2" or ".cr3" or ".dng" or ".nef" or ".orf" or ".raf" or ".rw2";
        if (!isRaw) return null;

        var dir = Path.GetDirectoryName(filePath) ?? "";
        var name = Path.GetFileNameWithoutExtension(filePath);
        var proxyDir = Path.Combine(dir, "Proxies");
        var proxyPath = Path.Combine(proxyDir, name + ".jpg");

        if (File.Exists(proxyPath) && IsFresherThan(filePath, proxyPath))
            return proxyPath;

        return null;
    }

    public static bool IsFresherThan(string sourcePath, string proxyPath)
    {
        try
        {
            var srcWrite = File.GetLastWriteTimeUtc(sourcePath);
            var proxyWrite = File.GetLastWriteTimeUtc(proxyPath);
            return proxyWrite >= srcWrite;
        }
        catch
        {
            return true;
        }
    }

    private PreviewResult? LoadPreviewDirect(string filePath, int maxWidth, int maxHeight)
    {
        try
        {
            using var source = new Bitmap(filePath);
            var pw = source.Width;
            var ph = source.Height;

            HandleOrientation(source, ref pw, ref ph, out var rotation);

            var (w, h) = FitDimensions(pw, ph, maxWidth, maxHeight);
            using var resized = new Bitmap(w, h, PixelFormat.Format32bppArgb);

            using (var g = System.Drawing.Graphics.FromImage(resized))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                if (rotation != 0)
                {
                    g.TranslateTransform(w / 2f, h / 2f);
                    g.RotateTransform(rotation);
                    g.TranslateTransform(-w / 2f, -h / 2f);
                }
                g.DrawImage(source, 0, 0, w, h);
            }

            var bitmapSource = BitmapToBitmapSource(resized);
            return new PreviewResult(bitmapSource, pw, ph, (double)pw / ph, true);
        }
        catch
        {
            return null;
        }
    }

    public (int Width, int Height)? GetPixelDimensions(string filePath)
    {
        try
        {
            using var source = new Bitmap(filePath);
            var w = source.Width;
            var h = source.Height;
            HandleOrientation(source, ref w, ref h, out _);
            return (w, h);
        }
        catch
        {
            return null;
        }
    }

    private static void HandleOrientation(Bitmap image, ref int w, ref int h, out float rotation)
    {
        rotation = 0;
        try
        {
            if (!image.PropertyIdList.Contains(0x0112)) return;
            var prop = image.GetPropertyItem(0x0112);
            if (prop?.Value == null || prop.Value.Length == 0) return;

            var orientation = prop.Value[0];
            switch (orientation)
            {
                case 6:
                    (w, h) = (h, w);
                    rotation = 90;
                    break;
                case 8:
                    (w, h) = (h, w);
                    rotation = 270;
                    break;
                case 3:
                    rotation = 180;
                    break;
            }
        }
        catch
        {
        }
    }

    private static (int w, int h) FitDimensions(int srcW, int srcH, int maxW, int maxH)
    {
        if (srcW <= 0 || srcH <= 0) return (maxW, maxH);
        var ratio = Math.Min((double)maxW / srcW, (double)maxH / srcH);
        return ((int)(srcW * ratio), (int)(srcH * ratio));
    }

    private static BitmapSource BitmapToBitmapSource(Bitmap bitmap)
    {
        var rect = new System.Drawing.Rectangle(0, 0, bitmap.Width, bitmap.Height);
        var data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, bitmap.PixelFormat);

        try
        {
            var bitmapSource = BitmapSource.Create(
                data.Width, data.Height, 96, 96,
                PixelFormats.Bgra32, null,
                data.Scan0, data.Stride * data.Height, data.Stride);

            bitmapSource.Freeze();
            return bitmapSource;
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

    public static bool SupportsDirectDecode(string path)
    {
        var ext = Path.GetExtension(path).ToLowerInvariant();
        return ext is ".jpg" or ".jpeg" or ".heic" or ".heif" or ".png" or ".tif" or ".tiff"
            or ".arw" or ".cr2" or ".cr3" or ".dng" or ".nef" or ".orf" or ".raf" or ".rw2";
    }
}
