using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PreStage.Core.Imaging;
using PreStage.Core.Models;

namespace PreStage.App.Controls;

public class GalleryPreviewPanel : Grid
{
    private readonly Image _previewImage;
    private readonly CropMaskOverlay _cropMask;
    private readonly CompositionGuideOverlay _guides;

    public static readonly DependencyProperty ImageSourceProperty =
        DependencyProperty.Register(nameof(ImageSource), typeof(ImageSource), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty ImageAspectRatioProperty =
        DependencyProperty.Register(nameof(ImageAspectRatio), typeof(double), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty CropAspectRatioProperty =
        DependencyProperty.Register(nameof(CropAspectRatio), typeof(double), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty DpiScaleProperty =
        DependencyProperty.Register(nameof(DpiScale), typeof(double), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty CropStyleProperty =
        DependencyProperty.Register(nameof(CropStyle), typeof(CropGuideStyle), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(CropGuideStyle.Mask, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty ActiveGuidesProperty =
        DependencyProperty.Register(nameof(ActiveGuides), typeof(HashSet<CompositionOverlay>), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(new HashSet<CompositionOverlay>(), FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty GuidesFollowCropProperty =
        DependencyProperty.Register(nameof(GuidesFollowCrop), typeof(bool), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty GuideColorProperty =
        DependencyProperty.Register(nameof(GuideColor), typeof(CompositionOverlayColor), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(CompositionOverlayColor.Gray, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public static readonly DependencyProperty GuideOpacityProperty =
        DependencyProperty.Register(nameof(GuideOpacity), typeof(double), typeof(GalleryPreviewPanel),
            new FrameworkPropertyMetadata(0.46, FrameworkPropertyMetadataOptions.AffectsRender, OnGeometryPropertyChanged));

    public ImageSource? ImageSource
    {
        get => (ImageSource?)GetValue(ImageSourceProperty);
        set => SetValue(ImageSourceProperty, value);
    }

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

    public HashSet<CompositionOverlay> ActiveGuides
    {
        get => (HashSet<CompositionOverlay>)GetValue(ActiveGuidesProperty);
        set => SetValue(ActiveGuidesProperty, value);
    }

    public bool GuidesFollowCrop
    {
        get => (bool)GetValue(GuidesFollowCropProperty);
        set => SetValue(GuidesFollowCropProperty, value);
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

    public GalleryPreviewPanel()
    {
        ClipToBounds = true;
        Background = Brushes.Transparent;

        _previewImage = new Image
        {
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };

        _cropMask = new CropMaskOverlay
        {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            IsHitTestVisible = false
        };

        _guides = new CompositionGuideOverlay
        {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            IsHitTestVisible = false
        };

        Children.Add(_previewImage);
        Children.Add(_cropMask);
        Children.Add(_guides);

        Loaded += (_, _) => PropagateProperties();
    }

    private void PropagateProperties()
    {
        _previewImage.Source = ImageSource;

        _cropMask.ImageAspectRatio = ImageAspectRatio;
        _cropMask.CropAspectRatio = CropAspectRatio;
        _cropMask.DpiScale = DpiScale;
        _cropMask.CropStyle = CropStyle;

        _guides.ImageAspectRatio = ImageAspectRatio;
        _guides.DpiScale = DpiScale;
        _guides.ActiveGuides = ActiveGuides;
        _guides.CropAspectRatio = CropAspectRatio;
        _guides.FollowCrop = GuidesFollowCrop;
        _guides.GuideColor = GuideColor;
        _guides.GuideOpacity = GuideOpacity;
    }

    private static void OnGeometryPropertyChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is GalleryPreviewPanel panel)
            panel.PropagateProperties();
    }

    protected override Size ArrangeOverride(Size arrangeSize)
    {
        var result = base.ArrangeOverride(arrangeSize);
        if (result.Width <= 0 || result.Height <= 0) return result;
        if (ImageAspectRatio <= 0) return result;
        try
        {
            var containerSize = new GeometrySize(result.Width, result.Height);
            var imageRect = PreviewRenderGeometry.ImageRect(ImageAspectRatio, containerSize, DpiScale);

            _previewImage.Arrange(new Rect(
                imageRect.X, imageRect.Y, imageRect.Width, imageRect.Height));

            _cropMask.Arrange(new Rect(0, 0, result.Width, result.Height));
            _guides.Arrange(new Rect(0, 0, result.Width, result.Height));
        }
        catch
        {
        }
        return result;
    }
}
