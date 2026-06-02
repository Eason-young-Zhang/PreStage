using System.Collections.Concurrent;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Security.Cryptography;
using System.Text;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class ThumbnailService
{
    private readonly string _cacheDir;
    private readonly ConcurrentDictionary<string, Bitmap> _memoryCache = new();
    private readonly int _maxMemoryEntries;

    public ThumbnailService(string? cacheDir = null, int maxMemoryEntries = 200)
    {
        _cacheDir = cacheDir ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PreStage", "Thumbnails");
        Directory.CreateDirectory(_cacheDir);
        _maxMemoryEntries = maxMemoryEntries;
    }

    public Bitmap? GetThumbnail(MediaItem item, int maxWidth, int maxHeight)
    {
        var cacheKey = GetCacheKey(item, maxWidth, maxHeight);

        if (_memoryCache.TryGetValue(cacheKey, out var cached))
            return (Bitmap)cached.Clone();

        var diskPath = GetDiskCachePath(cacheKey);
        if (File.Exists(diskPath))
        {
            var fromDisk = new Bitmap(diskPath);
            AddToMemoryCache(cacheKey, fromDisk);
            return (Bitmap)fromDisk.Clone();
        }

        var generated = GenerateThumbnail(item.Url, maxWidth, maxHeight);
        if (generated == null) return null;

        AddToMemoryCache(cacheKey, generated);

        try
        {
            generated.Save(diskPath, ImageFormat.Jpeg);
        }
        catch
        {
        }

        return (Bitmap)generated.Clone();
    }

    public void ClearMemoryCache()
    {
        foreach (var (_, bitmap) in _memoryCache)
        {
            bitmap.Dispose();
        }
        _memoryCache.Clear();
    }

    private Bitmap? GenerateThumbnail(string path, int maxWidth, int maxHeight)
    {
        try
        {
            using var source = new Bitmap(path);
            var (w, h) = FitDimensions(source.Width, source.Height, maxWidth, maxHeight);

            var result = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using var g = Graphics.FromImage(result);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.SmoothingMode = SmoothingMode.HighQuality;
            g.DrawImage(source, 0, 0, w, h);

            return result;
        }
        catch
        {
            return null;
        }
    }

    private static (int width, int height) FitDimensions(int srcW, int srcH, int maxW, int maxH)
    {
        if (srcW <= 0 || srcH <= 0) return (maxW, maxH);

        var ratio = Math.Min((double)maxW / srcW, (double)maxH / srcH);
        return ((int)(srcW * ratio), (int)(srcH * ratio));
    }

    private string GetCacheKey(MediaItem item, int maxWidth, int maxHeight)
    {
        var raw = $"{item.Url}|{item.FileSize}|{maxWidth}x{maxHeight}";
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
        return Convert.ToHexStringLower(hash);
    }

    private string GetDiskCachePath(string cacheKey)
    {
        return Path.Combine(_cacheDir, $"{cacheKey}.jpg");
    }

    private void AddToMemoryCache(string key, Bitmap bitmap)
    {
        if (_memoryCache.Count >= _maxMemoryEntries)
        {
            var toRemove = _memoryCache.Keys.FirstOrDefault();
            if (toRemove != null && _memoryCache.TryRemove(toRemove, out var old))
                old.Dispose();
        }
        _memoryCache[key] = (Bitmap)bitmap.Clone();
    }
}
