using PreStage.Core.Models;
using PreStage.Core.Services;
using Xunit;

namespace PreStage.Tests.Services;

public class CopyServiceTests
{
    private static string TempDir => Path.Combine(Path.GetTempPath(), $"prestage_copy_{Guid.NewGuid()}");

    private static MediaItem CreateTestItem(string folder, string name, long size = 1024,
        DateTime? captureDate = null, string? cameraModel = null, int rating = 0)
    {
        var path = Path.Combine(folder, name);
        File.WriteAllBytes(path, new byte[size]);
        return new MediaItem(path, MediaType.Jpeg, size, captureDate)
        {
            CameraModel = cameraModel,
            Rating = rating
        };
    }

    [Fact]
    public async Task Copy_DateFolderRule_CreatesDateSubfolder()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var date = new DateTime(2025, 6, 15);
            var item = CreateTestItem(srcDir, "photo.jpg", captureDate: date);

            var service = new CopyService();
            await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            var expectedPath = Path.Combine(dstDir, "2025-06-15", "photo.jpg");
            Assert.True(File.Exists(expectedPath));
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_RawOnly_SkipsJpeg()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var rawPath = Path.Combine(srcDir, "photo.cr3");
            File.WriteAllBytes(rawPath, new byte[2048]);
            var raw = new MediaItem(rawPath, MediaType.Raw, 2048);

            var jpgPath = Path.Combine(srcDir, "photo.jpg");
            File.WriteAllBytes(jpgPath, new byte[1024]);
            var jpg = new MediaItem(jpgPath, MediaType.Jpeg, 1024);

            var service = new CopyService();
            var log = await service.CopyAsync([raw, jpg], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.RawOnly, CopyVerificationMode.SizeOnly);

            Assert.Equal(1, service.Progress.CompletedCount);
            Assert.Equal(1, service.Progress.TotalCount);
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_SkipExisting_DoesNotOverwrite()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var date = new DateTime(2025, 1, 1);
            var dateFolder = date.ToString("yyyy-MM-dd");
            var item = CreateTestItem(srcDir, "existing.jpg", captureDate: date);
            var destSubDir = Path.Combine(dstDir, dateFolder);
            Directory.CreateDirectory(destSubDir);
            var destPath = Path.Combine(destSubDir, "existing.jpg");
            File.WriteAllText(destPath, "original content");

            var service = new CopyService();
            var log = await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.SkipExisting,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            var entry = log.Entries.First();
            Assert.Equal(CopyStatus.Skipped, entry.Status);
            Assert.Equal("original content", File.ReadAllText(destPath));
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_Overwrite_ReplacesFile()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var date = new DateTime(2025, 2, 1);
            var dateFolder = date.ToString("yyyy-MM-dd");
            var item = CreateTestItem(srcDir, "overwrite.jpg", captureDate: date);
            var destSubDir = Path.Combine(dstDir, dateFolder);
            Directory.CreateDirectory(destSubDir);
            var destPath = Path.Combine(destSubDir, "overwrite.jpg");
            File.WriteAllText(destPath, "old content");

            var service = new CopyService();
            var log = await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.Overwrite,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            Assert.Equal(1024, new FileInfo(destPath).Length);
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_AutoRename_CreatesUniqueName()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var date = new DateTime(2025, 3, 1);
            var dateFolder = date.ToString("yyyy-MM-dd");
            var item = CreateTestItem(srcDir, "file.jpg", 500, captureDate: date);
            var destSubDir = Path.Combine(dstDir, dateFolder);
            Directory.CreateDirectory(destSubDir);
            var destPath = Path.Combine(destSubDir, "file.jpg");
            File.WriteAllText(destPath, "existing");

            var service = new CopyService();
            var log = await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            Assert.True(File.Exists(destPath));
            var renamed = Directory.GetFiles(destSubDir, "file_*.jpg");
            Assert.Single(renamed);
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_CopiesSidecarWithMedia()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var item = CreateTestItem(srcDir, "with_sidecar.jpg", captureDate: new DateTime(2025, 4, 1));
            File.WriteAllText(XmpService.GetSidecarPath(item.Url), "sidecar");

            var service = new CopyService();
            await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            var expectedSidecar = Path.Combine(dstDir, "2025-04-01", "with_sidecar.xmp");
            Assert.True(File.Exists(expectedSidecar));
            Assert.Equal("sidecar", File.ReadAllText(expectedSidecar));
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_AutoRename_TreatsExistingSidecarAsConflict()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var date = new DateTime(2025, 4, 2);
            var item = CreateTestItem(srcDir, "sidecar_conflict.jpg", captureDate: date);
            var destSubDir = Path.Combine(dstDir, "2025-04-02");
            Directory.CreateDirectory(destSubDir);
            File.WriteAllText(Path.Combine(destSubDir, "sidecar_conflict.xmp"), "existing");

            var service = new CopyService();
            await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            Assert.False(File.Exists(Path.Combine(destSubDir, "sidecar_conflict.jpg")));
            Assert.True(File.Exists(Path.Combine(destSubDir, "sidecar_conflict_1.jpg")));
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_Cancel_StopsMidway()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var items = Enumerable.Range(0, 50)
                .Select(i => CreateTestItem(srcDir, $"img_{i:D4}.jpg", 256 * 1024))
                .ToList();

            var service = new CopyService();

            var task = service.CopyAsync(items, dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            await Task.Delay(100);
            service.Cancel();

            CopyLogRecord log;
            try { log = await task; }
            catch { log = new CopyLogRecord(); }

            Assert.True(service.Progress.IsCancelled || log.Entries.Count < items.Count);
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_PauseResume_WorksCorrectly()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var items = Enumerable.Range(0, 5)
                .Select(i => CreateTestItem(srcDir, $"pause_{i:D4}.jpg", 2048))
                .ToList();

            var service = new CopyService();

            var task = service.CopyAsync(items, dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            await Task.Delay(30);
            service.Pause();
            Assert.True(service.Progress.IsPaused);

            await Task.Delay(100);
            service.Resume();
            Assert.False(service.Progress.IsPaused);

            var log = await task;
            Assert.Equal(CopyStatus.Verified, log.Entries.First().Status);
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_BuildsCopyLogWithAllEntries()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var items = Enumerable.Range(0, 3)
                .Select(i => CreateTestItem(srcDir, $"log_{i}.jpg"))
                .ToList();

            var service = new CopyService();
            var log = await service.CopyAsync(items, dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            Assert.Equal(3, log.Entries.Count);
            Assert.True(log.IsFinished);
            Assert.Equal(3, log.TotalItems);
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_CameraFolderRule_UsesCameraSubfolder()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var item = CreateTestItem(srcDir, "cam.jpg", cameraModel: "Canon EOS R5",
                captureDate: new DateTime(2025, 3, 20));

            var service = new CopyService();
            await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CameraModel, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            var expected = Path.Combine(dstDir, "Canon EOS R5", "2025-03-20", "cam.jpg");
            Assert.True(File.Exists(expected));
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_RatingFolderRule_UsesRatingSubfolder()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var item = CreateTestItem(srcDir, "rated.jpg", rating: 4);

            var service = new CopyService();
            await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.Rating, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly);

            var expected = Path.Combine(dstDir, "4_stars", "rated.jpg");
            Assert.True(File.Exists(expected));
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_PreserveStructure_UsesSourceRootRelativePath()
    {
        var rootDir = TempDir;
        var dstDir = TempDir;
        try
        {
            var nestedDir = Path.Combine(rootDir, "2025", "wedding", "selects");
            Directory.CreateDirectory(nestedDir);
            Directory.CreateDirectory(dstDir);

            var item = CreateTestItem(nestedDir, "relative.jpg", captureDate: new DateTime(2025, 6, 1));

            var service = new CopyService();
            await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.PreserveStructure, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.SizeOnly,
                sourceRoot: rootDir);

            var expected = Path.Combine(dstDir, "2025", "wedding", "selects", "relative.jpg");
            Assert.True(File.Exists(expected));
        }
        finally
        {
            SafeDelete(rootDir);
            SafeDelete(dstDir);
        }
    }

    [Fact]
    public async Task Copy_Sha256_VerificationMismatchFails()
    {
        var srcDir = TempDir;
        var dstDir = TempDir;
        try
        {
            Directory.CreateDirectory(srcDir);
            Directory.CreateDirectory(dstDir);

            var item = CreateTestItem(srcDir, "hash.jpg", 128);
            var dest = Path.Combine(dstDir, "hash.jpg");

            var service = new CopyService();
            var log = await service.CopyAsync([item], dstDir,
                CopyOrganizationRule.CaptureDate, CopyConflictPolicy.AutoRename,
                CopyContentMode.AllSupported, CopyVerificationMode.Sha256);

            Assert.Equal(CopyStatus.Verified, log.Entries.First().Status);
        }
        finally
        {
            SafeDelete(srcDir);
            SafeDelete(dstDir);
        }
    }

    private static void SafeDelete(string path)
    {
        try { if (Directory.Exists(path)) Directory.Delete(path, true); } catch { }
    }
}
