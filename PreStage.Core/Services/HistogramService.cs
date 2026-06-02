namespace PreStage.Core.Services;

public class HistogramService
{
    public HistogramData Compute(RgbaBuffer buffer)
    {
        var data = new HistogramData();
        var pixels = buffer.Pixels;
        var total = buffer.Width * buffer.Height;

        for (var i = 0; i < total; i++)
        {
            var offset = i * 4;
            var b = pixels[offset];
            var g = pixels[offset + 1];
            var r = pixels[offset + 2];

            data.Red[r]++;
            data.Green[g]++;
            data.Blue[b]++;
            data.Luminance[(int)(0.299 * r + 0.587 * g + 0.114 * b)]++;
        }

        return data;
    }
}

public class HistogramData
{
    public int[] Red { get; } = new int[256];
    public int[] Green { get; } = new int[256];
    public int[] Blue { get; } = new int[256];
    public int[] Luminance { get; } = new int[256];

    public int MaxValue =>
        new[] { Red.Max(), Green.Max(), Blue.Max(), Luminance.Max() }.Max();
}
