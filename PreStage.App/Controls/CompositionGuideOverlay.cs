using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PreStage.Core.Imaging;
using PreStage.Core.Models;

namespace PreStage.App.Controls;

public class CompositionGuideOverlay : Canvas
{
    public static readonly DependencyProperty ImageAspectRatioProperty =
        DependencyProperty.Register(nameof(ImageAspectRatio), typeof(double), typeof(CompositionGuideOverlay),
            new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty DpiScaleProperty =
        DependencyProperty.Register(nameof(DpiScale), typeof(double), typeof(CompositionGuideOverlay),
            new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty ActiveGuidesProperty =
        DependencyProperty.Register(nameof(ActiveGuides), typeof(HashSet<CompositionOverlay>), typeof(CompositionGuideOverlay),
            new FrameworkPropertyMetadata(new HashSet<CompositionOverlay>(), FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty CropAspectRatioProperty =
        DependencyProperty.Register(nameof(CropAspectRatio), typeof(double), typeof(CompositionGuideOverlay),
            new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty FollowCropProperty =
        DependencyProperty.Register(nameof(FollowCrop), typeof(bool), typeof(CompositionGuideOverlay),
            new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty GuideColorProperty =
        DependencyProperty.Register(nameof(GuideColor), typeof(CompositionOverlayColor), typeof(CompositionGuideOverlay),
            new FrameworkPropertyMetadata(CompositionOverlayColor.Gray, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty GuideOpacityProperty =
        DependencyProperty.Register(nameof(GuideOpacity), typeof(double), typeof(CompositionGuideOverlay),
            new FrameworkPropertyMetadata(0.46, FrameworkPropertyMetadataOptions.AffectsRender));

    public double ImageAspectRatio
    {
        get => (double)GetValue(ImageAspectRatioProperty);
        set => SetValue(ImageAspectRatioProperty, value);
    }

    public double DpiScale
    {
        get => (double)GetValue(DpiScaleProperty);
        set => SetValue(DpiScaleProperty, value);
    }

    public HashSet<CompositionOverlay> ActiveGuides
    {
        get => (HashSet<CompositionOverlay>)GetValue(ActiveGuidesProperty);
        set => SetValue(ActiveGuidesProperty, value);
    }

    public double CropAspectRatio
    {
        get => (double)GetValue(CropAspectRatioProperty);
        set => SetValue(CropAspectRatioProperty, value);
    }

    public bool FollowCrop
    {
        get => (bool)GetValue(FollowCropProperty);
        set => SetValue(FollowCropProperty, value);
    }

    public CompositionOverlayColor GuideColor
    {
        get => (CompositionOverlayColor)GetValue(GuideColorProperty);
        set => SetValue(GuideColorProperty, value);
    }

    public double GuideOpacity
    {
        get => (double)GetValue(GuideOpacityProperty);
        set => SetValue(GuideOpacityProperty, value);
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        if (ActiveGuides.Count == 0) return;

        var containerSize = new GeometrySize(ActualWidth, ActualHeight);
        if (containerSize.Width <= 0 || containerSize.Height <= 0) return;

        var imageRect = PreviewRenderGeometry.ImageRect(ImageAspectRatio, containerSize, DpiScale);
        var boundaryRect = imageRect;
        if (FollowCrop && CropAspectRatio > 0)
        {
            var cropRect = PreviewRenderGeometry.CropRect(imageRect, CropAspectRatio, DpiScale);
            if (cropRect.Width > 0 && cropRect.Height > 0)
                boundaryRect = cropRect;
        }

        var guidePen = CreateGuidePen();

        foreach (var guide in ActiveGuides)
        {
            switch (guide)
            {
                case CompositionOverlay.Thirds:
                    DrawThirds(dc, boundaryRect, guidePen);
                    break;
                case CompositionOverlay.Center:
                    DrawCenter(dc, boundaryRect, guidePen);
                    break;
                case CompositionOverlay.Diagonals:
                    DrawDiagonals(dc, boundaryRect, guidePen);
                    break;
                case CompositionOverlay.GoldenRatio:
                    DrawGoldenRatio(dc, boundaryRect, guidePen);
                    break;
            }
        }
    }

    private Pen CreateGuidePen()
    {
        var alpha = (byte)(Math.Clamp(GuideOpacity, 0.1, 1.0) * 255);
        var color = GuideColor switch
        {
            CompositionOverlayColor.White => Color.FromArgb(alpha, 255, 255, 255),
            CompositionOverlayColor.Black => Color.FromArgb(alpha, 0, 0, 0),
            CompositionOverlayColor.Accent => Color.FromArgb(alpha, 0, 120, 212),
            _ => Color.FromArgb(alpha, 200, 200, 200)
        };
        return new Pen(new SolidColorBrush(color), 0.8);
    }

    private static void DrawThirds(DrawingContext dc, GeometryRect r, Pen pen)
    {
        var thirdW = r.Width / 3;
        var thirdH = r.Height / 3;
        dc.DrawLine(pen, new Point(r.X + thirdW, r.Y), new Point(r.X + thirdW, r.MaxY));
        dc.DrawLine(pen, new Point(r.X + thirdW * 2, r.Y), new Point(r.X + thirdW * 2, r.MaxY));
        dc.DrawLine(pen, new Point(r.X, r.Y + thirdH), new Point(r.MaxX, r.Y + thirdH));
        dc.DrawLine(pen, new Point(r.X, r.Y + thirdH * 2), new Point(r.MaxX, r.Y + thirdH * 2));
    }

    private static void DrawCenter(DrawingContext dc, GeometryRect r, Pen pen)
    {
        var cx = r.MidX;
        var cy = r.MidY;
        dc.DrawLine(pen, new Point(cx, r.Y), new Point(cx, r.MaxY));
        dc.DrawLine(pen, new Point(r.X, cy), new Point(r.MaxX, cy));
    }

    private static void DrawDiagonals(DrawingContext dc, GeometryRect r, Pen pen)
    {
        dc.DrawLine(pen, new Point(r.X, r.Y), new Point(r.MaxX, r.MaxY));
        dc.DrawLine(pen, new Point(r.MaxX, r.Y), new Point(r.X, r.MaxY));
    }

    private static void DrawGoldenRatio(DrawingContext dc, GeometryRect r, Pen pen)
    {
        var phi = 1.618;
        var w = r.Width / phi;
        var h = r.Height / phi;
        dc.DrawLine(pen, new Point(r.X + w, r.Y), new Point(r.X + w, r.MaxY));
        dc.DrawLine(pen, new Point(r.MaxX - w, r.Y), new Point(r.MaxX - w, r.MaxY));
        dc.DrawLine(pen, new Point(r.X, r.Y + h), new Point(r.MaxX, r.Y + h));
        dc.DrawLine(pen, new Point(r.X, r.MaxY - h), new Point(r.MaxX, r.MaxY - h));
    }
}
