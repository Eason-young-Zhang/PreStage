using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PreStage.Core.Models;

namespace PreStage.App.Controls;

public class WaveformView : Canvas
{
    public WaveformView()
    {
        Background = Brushes.Transparent;
    }

    public static readonly DependencyProperty WaveformProperty =
        DependencyProperty.Register(nameof(Waveform), typeof(int[][][]), typeof(WaveformView),
            new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty MaxValueProperty =
        DependencyProperty.Register(nameof(MaxValue), typeof(int), typeof(WaveformView),
            new FrameworkPropertyMetadata(1, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty ChannelModeProperty =
        DependencyProperty.Register(nameof(ChannelMode), typeof(WaveformChannelMode), typeof(WaveformView),
            new FrameworkPropertyMetadata(WaveformChannelMode.Luminance, FrameworkPropertyMetadataOptions.AffectsRender));

    public int[][][]? Waveform
    {
        get => (int[][][]?)GetValue(WaveformProperty);
        set => SetValue(WaveformProperty, value);
    }

    public int MaxValue
    {
        get => (int)GetValue(MaxValueProperty);
        set => SetValue(MaxValueProperty, value);
    }

    public WaveformChannelMode ChannelMode
    {
        get => (WaveformChannelMode)GetValue(ChannelModeProperty);
        set => SetValue(ChannelModeProperty, value);
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        if (Waveform == null) return;
        var w = (int)ActualWidth;
        var h = (int)ActualHeight;
        if (w <= 0 || h <= 0) return;

        var max = Math.Max(MaxValue, 1);
        var logMax = Math.Log(max + 1);
        var pixels = new byte[w * h * 4];
        var stride = w * 4;

        for (var y = 0; y < h; y++)
        {
            for (var x = 0; x < w; x++)
            {
                var px = x * Waveform.Length / w;
                var py = y * Waveform[0].Length / h;
                px = Math.Clamp(px, 0, Waveform.Length - 1);
                py = Math.Clamp(py, 0, Waveform[0].Length - 1);

                var p = Waveform[px][py];
                byte r;
                byte g;
                byte b;

                if (ChannelMode == WaveformChannelMode.Luminance)
                {
                    var lum = (byte)(Math.Log(p[0] + 1) / logMax * 255);
                    r = lum;
                    g = lum;
                    b = lum;
                }
                else
                {
                    r = ChannelMode is WaveformChannelMode.Rgb or WaveformChannelMode.Red
                        ? (byte)(Math.Log(p[0] + 1) / logMax * 255) : (byte)0;
                    g = ChannelMode is WaveformChannelMode.Rgb or WaveformChannelMode.Green
                        ? (byte)(Math.Log(p[1] + 1) / logMax * 255) : (byte)0;
                    b = ChannelMode is WaveformChannelMode.Rgb or WaveformChannelMode.Blue
                        ? (byte)(Math.Log(p[2] + 1) / logMax * 255) : (byte)0;
                }

                var offset = y * stride + x * 4;
                pixels[offset] = b;
                pixels[offset + 1] = g;
                pixels[offset + 2] = r;
                pixels[offset + 3] = 255;
            }
        }

        var bmp = BitmapSource.Create(w, h, 96, 96, PixelFormats.Bgra32, null, pixels, stride);
        dc.DrawImage(bmp, new Rect(0, 0, w, h));
    }
}
