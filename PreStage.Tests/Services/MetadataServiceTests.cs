using PreStage.Core.Models;
using PreStage.Core.Services;

namespace PreStage.Tests.Services;

public class MetadataServiceTests
{
    private static string TempDir => Path.Combine(Path.GetTempPath(), $"prestage_metadata_{Guid.NewGuid()}");

    [Fact]
    public void Enrich_ReadsAdjacentSidecar_WhenPresent()
    {
        var dir = TempDir;
        try
        {
            Directory.CreateDirectory(dir);
            var mediaPath = Path.Combine(dir, "IMG_0001.jpg");
            File.WriteAllBytes(mediaPath, [1, 2, 3, 4]);

            var sidecarPath = XmpService.GetSidecarPath(mediaPath);
            new XmpService().Write(sidecarPath, new XmpData
            {
                Rating = 5,
                Label = "Blue",
                PickState = PickState.Picked,
                CreatorTool = "PreStage.Tests"
            });

            var item = new MediaItem(mediaPath, MediaType.Jpeg, 4);

            new MetadataService().Enrich(item);

            Assert.Equal(5, item.Rating);
            Assert.Equal(ColorLabel.Blue, item.ColorLabel);
            Assert.Equal(PickState.Picked, item.PickState);
            Assert.Equal(XmpStatus.SidecarFound, item.XmpStatus);
        }
        finally
        {
            SafeDelete(dir);
        }
    }

    private static void SafeDelete(string path)
    {
        try
        {
            if (Directory.Exists(path))
                Directory.Delete(path, true);
        }
        catch
        {
        }
    }
}
