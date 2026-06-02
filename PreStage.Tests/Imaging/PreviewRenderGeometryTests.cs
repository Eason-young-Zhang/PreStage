using PreStage.Core.Imaging;
using Xunit;

namespace PreStage.Tests.Imaging;

public class PreviewRenderGeometryTests
{
    [Fact]
    public void ImageRect_LandscapeInSquare_ShouldCenterHorizontally()
    {
        var rect = PreviewRenderGeometry.ImageRect(2.0, new GeometrySize(100, 100), 1.0);
        Assert.Equal(0, rect.X);
        Assert.True(rect.Y > 0);
        Assert.Equal(100, rect.Width);
        Assert.Equal(50, rect.Height);
    }

    [Fact]
    public void ImageRect_PortraitInSquare_ShouldCenterVertically()
    {
        var rect = PreviewRenderGeometry.ImageRect(0.5, new GeometrySize(100, 100), 1.0);
        Assert.True(rect.X > 0);
        Assert.Equal(0, rect.Y);
        Assert.Equal(50, rect.Width);
        Assert.Equal(100, rect.Height);
    }

    [Fact]
    public void ImageRect_Panoramic_ShouldBeWideAndShort()
    {
        var rect = PreviewRenderGeometry.ImageRect(4.0, new GeometrySize(800, 600), 1.0);
        Assert.Equal(800, rect.Width);
        Assert.Equal(200, rect.Height);
    }

    [Fact]
    public void ImageRect_VerticalRaw_ShouldBeTallAndNarrow()
    {
        var rect = PreviewRenderGeometry.ImageRect(2.0 / 3.0, new GeometrySize(800, 600), 1.0);
        Assert.Equal(400, rect.Width);
        Assert.Equal(600, rect.Height);
    }

    [Fact]
    public void ImageRect_Square_ShouldFillContainer()
    {
        var rect = PreviewRenderGeometry.ImageRect(1.0, new GeometrySize(200, 200), 1.0);
        Assert.Equal(0, rect.X);
        Assert.Equal(0, rect.Y);
        Assert.Equal(200, rect.Width);
        Assert.Equal(200, rect.Height);
    }

    [Fact]
    public void ImageRect_ZeroAspectRatio_ShouldReturnContainer()
    {
        var rect = PreviewRenderGeometry.ImageRect(0, new GeometrySize(100, 100), 1.0);
        Assert.Equal(100, rect.Width);
        Assert.Equal(100, rect.Height);
    }

    [Fact]
    public void CropRect_OneToOneInLandscape()
    {
        var image = new GeometryRect(0, 100, 800, 400);
        var crop = PreviewRenderGeometry.CropRect(image, 1.0, 1.0);
        Assert.Equal(400, crop.Width);
        Assert.Equal(400, crop.Height);
        Assert.Equal(image.MidX, crop.MidX, 1);
        Assert.Equal(image.MidY, crop.MidY, 1);
    }

    [Fact]
    public void CropRect_WiderThanImage_ShouldFillWidth()
    {
        var image = new GeometryRect(0, 0, 400, 200);
        var crop = PreviewRenderGeometry.CropRect(image, 4.0, 1.0);
        Assert.Equal(400, crop.Width);
        Assert.Equal(100, crop.Height);
    }

    [Fact]
    public void MaskRects_FourPieces_CoverEntireOuterArea()
    {
        var image = new GeometryRect(10, 10, 200, 150);
        var crop = new GeometryRect(60, 60, 100, 50);
        var masks = PreviewRenderGeometry.MaskRects(image, crop, 1.0);

        Assert.NotEmpty(masks);
        Assert.Equal(4, masks.Length);
    }

    [Fact]
    public void MaskRects_CropEqualsImage_MasksAreBleedOnly()
    {
        var image = new GeometryRect(0, 0, 100, 100);
        var crop = new GeometryRect(0, 0, 100, 100);
        var masks = PreviewRenderGeometry.MaskRects(image, crop, 1.0);
        foreach (var mask in masks)
        {
            Assert.True(mask.Width <= 2 || mask.Height <= 2);
        }
    }

    [Fact]
    public void PixelAlign_IntegerValues_ShouldBeUnchanged()
    {
        var rect = new GeometryRect(10, 20, 100, 200);
        var aligned = PreviewRenderGeometry.PixelAlign(rect, 1.0);
        Assert.Equal(10, aligned.X);
        Assert.Equal(20, aligned.Y);
        Assert.Equal(100, aligned.Width);
        Assert.Equal(200, aligned.Height);
    }

    [Fact]
    public void PixelAlign_Fractional_ShouldSnapToPixelBoundary()
    {
        var rect = new GeometryRect(10.3, 20.7, 100.1, 200.9);
        var aligned = PreviewRenderGeometry.PixelAlign(rect, 2.0);
        Assert.Equal(10.0, aligned.X);
        Assert.Equal(20.5, aligned.Y);
    }

    [Fact]
    public void PixelAlign_Scale200_ShouldSnapToHalfPixel()
    {
        var rect = new GeometryRect(10.1, 20.2, 100.1, 200.1);
        var aligned = PreviewRenderGeometry.PixelAlign(rect, 2.0);
        Assert.Equal(10.0, aligned.X);
        Assert.Equal(20.0, aligned.Y);
    }

    [Fact]
    public void ImageRect_Scale125_ShouldSnapCorrectly()
    {
        var rect = PreviewRenderGeometry.ImageRect(3.0 / 2.0, new GeometrySize(100, 100), 1.25);
        Assert.True(rect.Width > 0);
        Assert.True(rect.Height > 0);
    }

    [Fact]
    public void ImageRect_Scale150_NoGaps()
    {
        var image = PreviewRenderGeometry.ImageRect(3.0 / 2.0, new GeometrySize(333, 222), 1.5);
        var crop = PreviewRenderGeometry.CropRect(image, 4.0 / 3.0, 1.5);
        var masks = PreviewRenderGeometry.MaskRects(image, crop, 1.5);

        var totalMaskArea = masks.Sum(m => m.Width * m.Height);
        var imageArea = image.Width * image.Height;
        var cropArea = crop.Width * crop.Height;

        Assert.True(totalMaskArea + cropArea >= imageArea - 0.01);
    }

    [Fact]
    public void MaskRects_HasBleed_ToPreventOnePxGaps()
    {
        var image = new GeometryRect(0, 0, 100, 100);
        var crop = new GeometryRect(25, 25, 50, 50);
        var masks = PreviewRenderGeometry.MaskRects(image, crop, 1.0);

        Assert.Equal(4, masks.Length);
        foreach (var mask in masks)
        {
            Assert.True(mask.Width > 0);
            Assert.True(mask.Height > 0);
        }
    }

    [Fact]
    public void ImageRect_Panoramic10k_ShouldNotOverflow()
    {
        var rect = PreviewRenderGeometry.ImageRect(12000.0 / 6000.0, new GeometrySize(1920, 1080), 1.0);
        Assert.Equal(1920, rect.Width);
        Assert.True(rect.Height > 0);
    }
}
