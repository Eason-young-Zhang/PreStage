using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public record MetadataCacheEntry(
    string Url, string Filename, long FileSize, DateTime? CaptureDate,
    string? CameraMake, string? CameraModel, string? LensModel,
    double? FocalLength, double? Aperture, string? ShutterSpeed, int? Iso,
    int? PixelWidth, int? PixelHeight, int? DisplayPixelWidth, int? DisplayPixelHeight,
    double DisplayRotationDegrees, string? ColorSpaceName, string? ColorProfileName
);

public class MetadataDiskCache
{
    public static MetadataDiskCache Instance { get; } = new();

    private static readonly string CacheDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "PreStage", "MetadataCache");

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = false
    };

    public MetadataCacheEntry? TryGet(string filePath)
    {
        try
        {
            var fileInfo = new FileInfo(filePath);
            if (!fileInfo.Exists)
                return null;

            var key = ComputeKey(filePath, fileInfo.Length, fileInfo.LastWriteTimeUtc);
            var cacheFilePath = GetCacheFilePath(key);

            if (!File.Exists(cacheFilePath))
                return null;

            var json = File.ReadAllText(cacheFilePath);
            return JsonSerializer.Deserialize<MetadataCacheEntry>(json);
        }
        catch
        {
            return null;
        }
    }

    public void Store(MediaItem item)
    {
        try
        {
            var key = GetCacheKey(item);
            var cacheFilePath = GetCacheFilePath(key);

            var entry = new MetadataCacheEntry(
                item.Url,
                item.Filename,
                item.FileSize,
                item.CaptureDate,
                item.CameraMake,
                item.CameraModel,
                item.LensModel,
                item.FocalLength,
                item.Aperture,
                item.ShutterSpeed,
                item.Iso,
                item.PixelWidth,
                item.PixelHeight,
                item.DisplayPixelWidth,
                item.DisplayPixelHeight,
                item.DisplayRotationDegrees,
                item.ColorSpaceName,
                item.ColorProfileName
            );

            var json = JsonSerializer.Serialize(entry, JsonOptions);

            Directory.CreateDirectory(CacheDir);
            File.WriteAllText(cacheFilePath, json);
        }
        catch
        {
        }
    }

    private string GetCacheKey(MediaItem item)
    {
        var fileInfo = new FileInfo(item.Url);
        return ComputeKey(item.Url, item.FileSize, fileInfo.LastWriteTimeUtc);
    }

    private static string ComputeKey(string filePath, long fileSize, DateTime lastWriteTimeUtc)
    {
        var raw = $"{filePath}|{fileSize}|{lastWriteTimeUtc:O}";
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
        return Convert.ToHexStringLower(hash);
    }

    private static string GetCacheFilePath(string key)
    {
        return Path.Combine(CacheDir, $"{key}.json");
    }
}
