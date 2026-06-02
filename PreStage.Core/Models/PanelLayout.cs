using System.Text.Json.Serialization;

namespace PreStage.Core.Models;

public sealed class PanelLayout
{
    public const double MinimumSidebarWidth = 340;
    public const double DefaultSidebarWidth = 408;
    public const double MaximumSidebarWidth = 560;

    public double SidebarWidth { get; set; } = DefaultSidebarWidth;
    public double PreviewWidth { get; set; } = 260;
    public double GalleryStripHeight { get; set; } = 84;
    public bool IsFilmstripCollapsed { get; set; }
    public double GridThumbnailScale { get; set; } = 1.0;
    public bool? SourceSectionExpanded { get; set; }
    public bool? TargetSectionExpanded { get; set; }
    public bool? FiltersSectionExpanded { get; set; }
    public FolderBrowserScale FolderBrowserScale { get; set; } = FolderBrowserScale.Small;
    public double? SourceFolderBrowserHeight { get; set; }
    public double? TargetFolderBrowserHeight { get; set; }
    public HistogramPlacement HistogramPlacement { get; set; } = HistogramPlacement.Floating;
    public double HistogramFloatingOffsetX { get; set; }
    public double HistogramFloatingOffsetY { get; set; }
    public double HistogramFloatingWidth { get; set; } = 230;
    public double HistogramFloatingHeight { get; set; } = 112;
    public HistogramCorner? HistogramFloatingAnchor { get; set; } = HistogramCorner.TopRight;
    public HistogramDisplayMode HistogramDisplayMode { get; set; } = HistogramDisplayMode.RgbAndLuminance;
    public HistogramPlacement WaveformPlacement { get; set; } = HistogramPlacement.Hidden;
    public double WaveformFloatingOffsetX { get; set; }
    public double WaveformFloatingOffsetY { get; set; }
    public double WaveformFloatingWidth { get; set; } = 260;
    public double WaveformFloatingHeight { get; set; } = 128;
    public HistogramCorner? WaveformFloatingAnchor { get; set; } = HistogramCorner.TopLeft;
    public WaveformDirection WaveformDirection { get; set; } = WaveformDirection.HorizontalX;
    public WaveformChannelMode WaveformChannelMode { get; set; } = WaveformChannelMode.Luminance;
    public HashSet<CompositionOverlay> CompositionOverlays { get; set; } = [];
    public CompositionOverlayColor CompositionOverlayColor { get; set; } = CompositionOverlayColor.Gray;
    public double CompositionOverlayOpacity { get; set; } = 0.46;
    public bool CompositionGuidesFollowCrop { get; set; }
    public CropGuideRatio CropGuideRatio { get; set; } = CropGuideRatio.Hidden;
    public CropGuideStyle CropGuideStyle { get; set; } = CropGuideStyle.Mask;
    public CropGuideOrientation CropGuideOrientation { get; set; } = CropGuideOrientation.Automatic;
    public List<CustomCropGuideRatio> CustomCropGuideRatios { get; set; } = [];
    public Guid? ActiveCustomCropGuideRatioId { get; set; }
    public AppAppearanceMode AppAppearance { get; set; } = AppAppearanceMode.System;
    public PreviewBackgroundTone PreviewBackground { get; set; } = PreviewBackgroundTone.System;
    public ReviewMatteSize ReviewMatteSize { get; set; } = ReviewMatteSize.None;
    public ToolbarDisplayMode ToolbarDisplayMode { get; set; } = ToolbarDisplayMode.IconOnly;

    public double? ActiveCropGuideAspectRatio(MediaItem item)
    {
        if (ActiveCustomCropGuideRatioId.HasValue)
        {
            var custom = CustomCropGuideRatios
                .FirstOrDefault(r => r.Id == ActiveCustomCropGuideRatioId.Value);
            if (custom != null)
                return custom.AspectRatioFor(item, CropGuideOrientation);
        }
        return CropGuideRatio switch
        {
            Models.CropGuideRatio.Hidden => null,
            Models.CropGuideRatio.Original => item.DisplayAspectRatio,
            Models.CropGuideRatio.OneToOne => 1.0,
            Models.CropGuideRatio.FourThree => OrientedAspect(4.0, 3.0, item, CropGuideOrientation),
            Models.CropGuideRatio.ThreeTwo => OrientedAspect(3.0, 2.0, item, CropGuideOrientation),
            Models.CropGuideRatio.SixteenNine => OrientedAspect(16.0, 9.0, item, CropGuideOrientation),
            Models.CropGuideRatio.FiveFour => OrientedAspect(5.0, 4.0, item, CropGuideOrientation),
            Models.CropGuideRatio.NineSixteen => OrientedAspect(9.0, 16.0, item, CropGuideOrientation),
            _ => null
        };
    }

    private static double OrientedAspect(double w, double h, MediaItem item,
        CropGuideOrientation orientation)
    {
        var baseRatio = w / h;
        if (orientation == CropGuideOrientation.Landscape)
            return Math.Max(baseRatio, 1.0 / baseRatio);
        if (orientation == CropGuideOrientation.Portrait)
            return Math.Min(baseRatio, 1.0 / baseRatio);

        var isPortrait = (item.DisplayAspectRatio ?? baseRatio) < 1.0;
        if (isPortrait && baseRatio > 1.0) return 1.0 / baseRatio;
        if (!isPortrait && baseRatio < 1.0) return 1.0 / baseRatio;
        return baseRatio;
    }
}

public sealed class CustomCropGuideRatio
{
    public const int MaximumSavedCount = 10;

    public Guid Id { get; init; } = Guid.NewGuid();
    public string Name { get; init; }
    public double Width { get; init; }
    public double Height { get; init; }

    public CustomCropGuideRatio(string name, double width, double height)
    {
        Name = name.Trim();
        Width = Math.Max(0.1, width);
        Height = Math.Max(0.1, height);
    }

    [JsonConstructor]
    public CustomCropGuideRatio(Guid id, string name, double width, double height)
        : this(name, width, height)
    {
        Id = id;
    }

    public double AspectRatioFor(MediaItem item, CropGuideOrientation orientation)
    {
        var baseRatio = Width / Height;
        if (orientation == CropGuideOrientation.Landscape)
            return Math.Max(baseRatio, 1.0 / baseRatio);
        if (orientation == CropGuideOrientation.Portrait)
            return Math.Min(baseRatio, 1.0 / baseRatio);

        var isPortrait = (item.DisplayAspectRatio ?? baseRatio) < 1.0;
        if (isPortrait && baseRatio > 1.0) return 1.0 / baseRatio;
        if (!isPortrait && baseRatio < 1.0) return 1.0 / baseRatio;
        return baseRatio;
    }
}
