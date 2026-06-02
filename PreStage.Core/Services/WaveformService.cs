namespace PreStage.Core.Services;

public class WaveformService
{
    public WaveformData ComputeX(RgbaBuffer buffer, int targetWidth = 256, int targetHeight = 192)
    {
        var data = new WaveformData(targetWidth, targetHeight);
        var scaleX = (double)buffer.Width / targetWidth;
        var scaleY = (double)buffer.Height / targetHeight;

        for (var y = 0; y < buffer.Height; y++)
        {
            for (var x = 0; x < buffer.Width; x++)
            {
                var offset = (y * buffer.Width + x) * 4;
                var b = buffer.Pixels[offset];
                var g = buffer.Pixels[offset + 1];
                var r = buffer.Pixels[offset + 2];
                var luma = (byte)(0.299 * r + 0.587 * g + 0.114 * b);

                var wx = (int)(x / scaleX);
                var wy = (int)((255 - luma) * targetHeight / 256.0);
                wy = Math.Clamp(wy, 0, targetHeight - 1);

                data.Increment(wx, wy, r, g, b);
            }
        }

        return data;
    }

    public WaveformData ComputeY(RgbaBuffer buffer, int targetWidth = 256, int targetHeight = 192)
    {
        var data = new WaveformData(targetWidth, targetHeight);
        var scaleX = (double)buffer.Width / targetWidth;
        var scaleY = (double)buffer.Height / targetHeight;

        for (var x = 0; x < buffer.Width; x++)
        {
            for (var y = 0; y < buffer.Height; y++)
            {
                var offset = (y * buffer.Width + x) * 4;
                var b = buffer.Pixels[offset];
                var g = buffer.Pixels[offset + 1];
                var r = buffer.Pixels[offset + 2];
                var luma = (byte)(0.299 * r + 0.587 * g + 0.114 * b);

                var wx = (int)(y / scaleY);
                var wy = (int)((255 - luma) * targetHeight / 256.0);
                wy = Math.Clamp(wy, 0, targetHeight - 1);

                data.Increment(wx, wy, r, g, b);
            }
        }

        return data;
    }
}

public class WaveformData
{
    public int Width { get; }
    public int Height { get; }
    public int[][][] Pixels { get; }

    public WaveformData(int width, int height)
    {
        Width = width;
        Height = height;
        Pixels = new int[width][][];
        for (var x = 0; x < width; x++)
        {
            Pixels[x] = new int[height][];
            for (var y = 0; y < height; y++)
                Pixels[x][y] = new int[3];
        }
    }

    public void Increment(int x, int y, int r, int g, int b)
    {
        var p = Pixels[x][y];
        p[0] = Math.Min(p[0] + r, 32768);
        p[1] = Math.Min(p[1] + g, 32768);
        p[2] = Math.Min(p[2] + b, 32768);
    }

    public int MaxValue
    {
        get
        {
            var max = 1;
            for (var x = 0; x < Width; x++)
            for (var y = 0; y < Height; y++)
            {
                var p = Pixels[x][y];
                max = Math.Max(max, Math.Max(p[0], Math.Max(p[1], p[2])));
            }
            return max;
        }
    }
}
