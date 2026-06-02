using System.Drawing;
using System.Drawing.Imaging;

namespace PreStage.Core.Services;

public class ImageAnalysisService
{
    private readonly Dictionary<string, RgbaBuffer> _cache = new();

    public RgbaBuffer? GetRgbaBuffer(string filePath, int maxWidth = 1024)
    {
        var key = $"{filePath}|{maxWidth}";
        if (_cache.TryGetValue(key, out var cached))
            return cached;

        try
        {
            using var source = new Bitmap(filePath);
            var (w, h) = FitDimensions(source.Width, source.Height, maxWidth, maxWidth);
            using var resized = new Bitmap(w, h, PixelFormat.Format32bppArgb);

            using (var g = System.Drawing.Graphics.FromImage(resized))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(source, 0, 0, w, h);
            }

            var rect = new System.Drawing.Rectangle(0, 0, w, h);
            var data = resized.LockBits(rect, ImageLockMode.ReadOnly, resized.PixelFormat);
            var pixels = new byte[data.Stride * h];
            System.Runtime.InteropServices.Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);
            resized.UnlockBits(data);

            var buffer = new RgbaBuffer(w, h, pixels);
            _cache[key] = buffer;
            return buffer;
        }
        catch
        {
            return null;
        }
    }

    public void ClearCache() => _cache.Clear();

    private static (int w, int h) FitDimensions(int srcW, int srcH, int maxW, int maxH)
    {
        if (srcW <= 0 || srcH <= 0) return (maxW, maxH);
        var ratio = Math.Min((double)maxW / srcW, (double)maxH / srcH);
        return ((int)(srcW * ratio), (int)(srcH * ratio));
    }
}

public class RgbaBuffer
{
    public int Width { get; }
    public int Height { get; }
    public byte[] Pixels { get; }

    public RgbaBuffer(int width, int height, byte[] pixels)
    {
        Width = width;
        Height = height;
        Pixels = pixels;
    }

    public int Stride => Width * 4;
}
