using PreStage.Core.Models;
using PreStage.Core.Services;
using Xunit;

namespace PreStage.Tests.Services;

public class MetadataDiskCacheTests
{
    private static string TempDir => Path.Combine(Path.GetTempPath(), $"prestage_cache_{Guid.NewGuid()}");

    [Fact]
    public void StoreAndRetrieve_RoundTripsCorrectly()
    {
        var dir = TempDir;
        try
        {
            Directory.CreateDirectory(dir);
            var filePath = Path.Combine(dir, "test.jpg");
            File.WriteAllBytes(filePath, new byte[4096]);

            var item = new MediaItem(filePath, MediaType.Jpeg, 4096)
            {
                CaptureDate = new DateTime(2025, 6, 15, 10, 30, 0),
                CameraMake = "Canon",
                CameraModel = "EOS R5",
                LensModel = "RF 24-70mm F2.8L",
                FocalLength = 50.0,
                Aperture = 2.8,
                ShutterSpeed = "1/500",
                Iso = 800,
                PixelWidth = 8192,
                PixelHeight = 5464,
                DisplayPixelWidth = 8192,
                DisplayPixelHeight = 5464,
                DisplayRotationDegrees = 0,
                ColorSpaceName = "sRGB",
                ColorProfileName = "sRGB IEC61966-2.1"
            };

            var cache = new MetadataDiskCache();
            cache.Store(item);

            var result = cache.TryGet(filePath);
            Assert.NotNull(result);
            Assert.Equal("Canon", result.CameraMake);
            Assert.Equal("EOS R5", result.CameraModel);
            Assert.Equal("RF 24-70mm F2.8L", result.LensModel);
            Assert.Equal(50.0, result.FocalLength);
            Assert.Equal(2.8, result.Aperture);
            Assert.Equal("1/500", result.ShutterSpeed);
            Assert.Equal(800, result.Iso);
            Assert.Equal(8192, result.PixelWidth);
            Assert.Equal(5464, result.PixelHeight);
            Assert.Equal(2025, result.CaptureDate?.Year);
            Assert.Equal(6, result.CaptureDate?.Month);
        }
        finally
        {
            SafeDelete(dir);
        }
    }

    [Fact]
    public void TryGet_NonexistentFile_ReturnsNull()
    {
        var result = new MetadataDiskCache().TryGet(@"C:\nonexistent_file_for_test.jpg");
        Assert.Null(result);
    }

    [Fact]
    public void TryGet_FileModified_KeyMismatches_ReturnsNull()
    {
        var dir = TempDir;
        try
        {
            Directory.CreateDirectory(dir);
            var filePath = Path.Combine(dir, "mod.jpg");
            File.WriteAllBytes(filePath, new byte[2048]);

            var item = new MediaItem(filePath, MediaType.Jpeg, 2048)
            {
                CameraMake = "Nikon"
            };

            var cache = new MetadataDiskCache();
            cache.Store(item);

            File.WriteAllBytes(filePath, new byte[4096]);

            var result = cache.TryGet(filePath);
            Assert.Null(result);
        }
        finally
        {
            SafeDelete(dir);
        }
    }

    private static void SafeDelete(string path)
    {
        try { if (Directory.Exists(path)) Directory.Delete(path, true); } catch { }
    }
}
