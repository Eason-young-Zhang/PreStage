using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using PreStage.Core.Imaging;
using PreStage.Core.Models;

namespace PreStage.App.Controls;

public class CropMaskOverlay : Canvas
{
    public static readonly DependencyProperty ImageAspectRatioProperty =
        DependencyProperty.Register(nameof(ImageAspectRatio), typeof(double), typeof(CropMaskOverlay),
            new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty CropAspectRatioProperty =
        DependencyProperty.Register(nameof(CropAspectRatio), typeof(double), typeof(CropMaskOverlay),
            new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty DpiScaleProperty =
        DependencyProperty.Register(nameof(DpiScale), typeof(double), typeof(CropMaskOverlay),
            new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty CropStyleProperty =
        DependencyProperty.Register(nameof(CropStyle), typeof(CropGuideStyle), typeof(CropMaskOverlay),
            new FrameworkPropertyMetadata(CropGuideStyle.Mask, FrameworkPropertyMetadataOptions.AffectsRender));

    public double ImageAspectRatio
    {
        get => (double)GetValue(ImageAspectRatioProperty);
        set => SetValue(ImageAspectRatioProperty, value);
    }

    public double CropAspectRatio
    {
        get => (double)GetValue(CropAspectRatioProperty);
        set => SetValue(CropAspectRatioProperty, value);
    }

    public double DpiScale
    {
        get => (double)GetValue(DpiScaleProperty);
        set => SetValue(DpiScaleProperty, value);
    }

    public CropGuideStyle CropStyle
    {
        get => (CropGuideStyle)GetValue(CropStyleProperty);
        set => SetValue(CropStyleProperty, value);
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        if (CropAspectRatio <= 0 || ImageAspectRatio <= 0) return;

        var containerSize = new GeometrySize(ActualWidth, ActualHeight);
        if (containerSize.Width <= 0 || containerSize.Height <= 0) return;

        var imageRect = PreviewRenderGeometry.ImageRect(ImageAspectRatio, containerSize, DpiScale);
        var cropRect = PreviewRenderGeometry.CropRect(imageRect, CropAspectRatio, DpiScale);

        if (CropStyle == CropGuideStyle.Mask)
        {
            var masks = PreviewRenderGeometry.MaskRects(imageRect, cropRect, DpiScale);
            var maskBrush = new SolidColorBrush(Color.FromArgb(160, 0, 0, 0));
            foreach (var mask in masks)
            {
                dc.DrawRectangle(maskBrush, null,
                    new Rect(mask.X, mask.Y, mask.Width, mask.Height));
            }
        }
        else
        {
            var pen = new Pen(Brushes.White, 1.5);
            dc.DrawRectangle(null, pen,
                new Rect(cropRect.X, cropRect.Y, cropRect.Width, cropRect.Height));
        }
    }
}
