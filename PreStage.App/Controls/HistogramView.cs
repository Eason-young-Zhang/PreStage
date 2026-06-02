using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;

namespace PreStage.App.Controls;

public class HistogramView : Canvas
{
    public static readonly DependencyProperty DataProperty =
        DependencyProperty.Register(nameof(Data), typeof(int[][]), typeof(HistogramView),
            new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty DisplayModeProperty =
        DependencyProperty.Register(nameof(DisplayMode), typeof(string), typeof(HistogramView),
            new FrameworkPropertyMetadata("RgbAndLuminance", FrameworkPropertyMetadataOptions.AffectsRender));

    public int[][]? Data
    {
        get => (int[][]?)GetValue(DataProperty);
        set => SetValue(DataProperty, value);
    }

    public string DisplayMode
    {
        get => (string)GetValue(DisplayModeProperty);
        set => SetValue(DisplayModeProperty, value);
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        if (Data == null || Data.Length < 4) return;

        var w = ActualWidth;
        var h = ActualHeight;
        if (w <= 0 || h <= 0) return;

        var mode = DisplayMode ?? "RgbAndLuminance";

        var drawRed = mode is "RgbAndLuminance" or "Rgb" or "Red";
        var drawGreen = mode is "RgbAndLuminance" or "Rgb" or "Green";
        var drawBlue = mode is "RgbAndLuminance" or "Rgb" or "Blue";
        var drawLuminance = mode is "RgbAndLuminance" or "Luminance";

        var maxVal = 1;
        if (drawRed && Data[0] is { Length: > 0 } r) maxVal = Math.Max(maxVal, r.Max());
        if (drawGreen && Data[1] is { Length: > 0 } g) maxVal = Math.Max(maxVal, g.Max());
        if (drawBlue && Data[2] is { Length: > 0 } b) maxVal = Math.Max(maxVal, b.Max());
        if (drawLuminance && Data[3] is { Length: > 0 } lum) maxVal = Math.Max(maxVal, lum.Max());

        var factor = h / Math.Log(maxVal + 1);

        if (drawRed) DrawChannel(dc, Data[0], w, h, factor, Color.FromArgb(200, 255, 60, 60));
        if (drawGreen) DrawChannel(dc, Data[1], w, h, factor, Color.FromArgb(160, 60, 255, 60));
        if (drawBlue) DrawChannel(dc, Data[2], w, h, factor, Color.FromArgb(160, 60, 100, 255));
        if (drawLuminance) DrawLuminanceLine(dc, Data[3], w, h, factor);
    }

    private static void DrawChannel(DrawingContext dc, int[] values, double w, double h,
        double factor, Color color)
    {
        if (values.Length == 0) return;
        var pen = new Pen(new SolidColorBrush(color), 0.8);
        var step = w / 256.0;
        var path = new PathGeometry();
        var figure = new PathFigure { StartPoint = new Point(0, h) };

        for (var i = 0; i < 256; i++)
        {
            var x = i * step;
            var y = h - Math.Log(values[i] + 1) * factor;
            figure.Segments.Add(new LineSegment(new Point(x, y), true));
        }

        figure.Segments.Add(new LineSegment(new Point(w, h), true));
        path.Figures.Add(figure);

        var brush = new SolidColorBrush(Color.FromArgb(40, color.R, color.G, color.B));
        dc.DrawGeometry(brush, pen, path);
    }

    private static void DrawLuminanceLine(DrawingContext dc, int[] values, double w, double h, double factor)
    {
        if (values.Length == 0) return;
        var pen = new Pen(Brushes.White, 1.0);
        var step = w / 256.0;
        var geometry = new StreamGeometry();
        using (var ctx = geometry.Open())
        {
            ctx.BeginFigure(new Point(0, h - Math.Log(values[0] + 1) * factor), false, false);
            for (var i = 1; i < 256; i++)
            {
                var x = i * step;
                var y = h - Math.Log(values[i] + 1) * factor;
                ctx.LineTo(new Point(x, y), true, false);
            }
        }
        dc.DrawGeometry(null, pen, geometry);
    }
}
