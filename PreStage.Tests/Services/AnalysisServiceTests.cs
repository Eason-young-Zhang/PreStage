using PreStage.Core.Services;
using Xunit;

namespace PreStage.Tests.Services;

public class HistogramServiceTests
{
    [Fact]
    public void Compute_BlackImage_AllZeros()
    {
        var buffer = new RgbaBuffer(10, 10, new byte[400]);
        var service = new HistogramService();
        var data = service.Compute(buffer);

        Assert.Equal(100, data.Red[0]);
        Assert.Equal(100, data.Green[0]);
        Assert.Equal(100, data.Blue[0]);
        Assert.Equal(100, data.Luminance[0]);
        Assert.Equal(0, data.Red[128]);
    }

    [Fact]
    public void Compute_WhiteImage_AllAt255()
    {
        var pixels = new byte[400];
        for (var i = 0; i < 400; i++) pixels[i] = 255;
        var buffer = new RgbaBuffer(10, 10, pixels);
        var service = new HistogramService();
        var data = service.Compute(buffer);

        Assert.Equal(100, data.Red[255]);
        Assert.Equal(100, data.Green[255]);
        Assert.Equal(100, data.Blue[255]);
        Assert.Equal(100, data.Luminance[255]);
    }

    [Fact]
    public void Compute_RedImage_OnlyRedChannel()
    {
        var pixels = new byte[40];
        for (var i = 0; i < 40; i += 4) pixels[i + 2] = 200;
        var buffer = new RgbaBuffer(10, 1, pixels);
        var service = new HistogramService();
        var data = service.Compute(buffer);

        Assert.Equal(10, data.Red[200]);
        Assert.Equal(10, data.Green[0]);
        Assert.Equal(10, data.Blue[0]);
    }

    [Fact]
    public void MaxValue_ReturnsMaxAcrossAllChannels()
    {
        var pixels = new byte[16];
        pixels[2] = 250;
        pixels[5] = 100;
        var buffer = new RgbaBuffer(4, 1, pixels);
        var service = new HistogramService();
        var data = service.Compute(buffer);

        Assert.True(data.MaxValue > 0);
        Assert.Equal(1, data.Red[250]);
    }
}

public class WaveformServiceTests
{
    [Fact]
    public void ComputeX_ReturnsCorrectDimensions()
    {
        var pixels = new byte[1600];
        for (var i = 0; i < 400; i++)
        {
            var off = i * 4;
            pixels[off] = 100;
            pixels[off + 1] = 150;
            pixels[off + 2] = 200;
        }

        var buffer = new RgbaBuffer(20, 20, pixels);
        var service = new WaveformService();
        var data = service.ComputeX(buffer, 256, 192);

        Assert.Equal(256, data.Width);
        Assert.Equal(192, data.Height);
    }

    [Fact]
    public void ComputeY_ReturnsCorrectDimensions()
    {
        var pixels = new byte[400];
        for (var i = 0; i < 100; i++)
        {
            var off = i * 4;
            pixels[off + 2] = 255;
        }

        var buffer = new RgbaBuffer(10, 10, pixels);
        var service = new WaveformService();
        var data = service.ComputeY(buffer, 128, 96);

        Assert.Equal(128, data.Width);
        Assert.Equal(96, data.Height);
        Assert.True(data.MaxValue > 0);
    }

    [Fact]
    public void MaxValue_ReflectsPixelData()
    {
        var pixels = new byte[40];
        for (var i = 0; i < 10; i++)
        {
            var off = i * 4;
            pixels[off] = 255;
            pixels[off + 1] = 255;
            pixels[off + 2] = 255;
        }

        var buffer = new RgbaBuffer(10, 1, pixels);
        var service = new WaveformService();
        var data = service.ComputeX(buffer, 64, 48);

        Assert.True(data.MaxValue > 0);
    }
}

public class ImageAnalysisServiceTests
{
    [Fact]
    public void ClearCache_RemovesEntries()
    {
        var service = new ImageAnalysisService();
        service.ClearCache();
    }
}
