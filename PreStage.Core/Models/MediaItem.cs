namespace PreStage.Core.Models;

public sealed class MediaItem
{
    public Guid Id { get; init; }
    public string Url { get; init; }
    public string Filename { get; init; }
    public string FileExtension { get; init; }
    public MediaType MediaType { get; init; }
    public long FileSize { get; init; }
    public DateTime? CaptureDate { get; set; }
    public DateTime? AddedDate { get; set; }
    public DateTime? CreatedDate { get; set; }
    public DateTime? ModifiedDate { get; set; }
    public DateTime? LastOpenedDate { get; set; }
    public string? CameraMake { get; set; }
    public string? CameraModel { get; set; }
    public string? LensModel { get; set; }
    public double? FocalLength { get; set; }
    public double? Aperture { get; set; }
    public string? ShutterSpeed { get; set; }
    public int? Iso { get; set; }
    public int? PixelWidth { get; set; }
    public int? PixelHeight { get; set; }
    public int? DisplayPixelWidth { get; set; }
    public int? DisplayPixelHeight { get; set; }
    public double DisplayRotationDegrees { get; set; }
    public string? ColorSpaceName { get; set; }
    public string? ColorProfileName { get; set; }
    public int Rating { get; set; }
    public ColorLabel? ColorLabel { get; set; }
    public PickState PickState { get; set; } = PickState.Unmarked;
    public CopyStatus CopyStatus { get; set; } = CopyStatus.NotCopied;
    public XmpStatus XmpStatus { get; set; } = XmpStatus.None;
    public string ThumbnailCacheKey { get; set; }
    public string? PairedAssetKey { get; set; }
    public string? PerceptualHash { get; set; }
    public Guid? SimilarityGroupId { get; set; }

    public MediaItem(string url, MediaType mediaType, long fileSize,
        DateTime? captureDate = null, DateTime? addedDate = null,
        DateTime? createdDate = null, DateTime? modifiedDate = null,
        DateTime? lastOpenedDate = null)
    {
        Id = Guid.NewGuid();
        Url = url;
        Filename = Path.GetFileName(url);
        FileExtension = Path.GetExtension(url).TrimStart('.').ToLowerInvariant();
        MediaType = mediaType;
        FileSize = fileSize;
        CaptureDate = captureDate;
        AddedDate = addedDate;
        CreatedDate = createdDate;
        ModifiedDate = modifiedDate;
        LastOpenedDate = lastOpenedDate;
        ThumbnailCacheKey = url;
    }

    public double? DisplayAspectRatio
    {
        get
        {
            var (w, h) = DisplayDimensions;
            if (w <= 0 || h <= 0) return null;
            return (double)w / h;
        }
    }

    public (int Width, int Height) DisplayDimensions
    {
        get
        {
            if (DisplayPixelWidth is > 0 && DisplayPixelHeight is > 0)
                return (DisplayPixelWidth.Value, DisplayPixelHeight.Value);

            if (PixelWidth is not > 0 || PixelHeight is not > 0)
                return (0, 0);

            var rot = NormalizedQuarterTurn(DisplayRotationDegrees);
            return rot is 90 or 270
                ? (PixelHeight.Value, PixelWidth.Value)
                : (PixelWidth.Value, PixelHeight.Value);
        }
    }

    public double? GetDisplayAspectRatio(double rotationDegrees)
    {
        var baseRatio = DisplayAspectRatio;
        if (baseRatio is not > 0) return null;
        var rot = NormalizedQuarterTurn(rotationDegrees);
        return rot is 90 or 270 ? 1.0 / baseRatio.Value : baseRatio;
    }

    private static int NormalizedQuarterTurn(double degrees)
    {
        return ((int)Math.Round(degrees) % 360 + 360) % 360;
    }
}

public struct MediaTransform
{
    public double RotationDegrees { get; set; }
    public bool FlippedHorizontally { get; set; }
    public bool FlippedVertically { get; set; }
}
