namespace PreStage.Core.Models;

public enum MediaType
{
    Raw,
    Jpeg,
    Heic,
    Tiff,
    Png,
    Video,
    Unknown
}

public enum PickState
{
    Unmarked,
    Picked,
    Rejected
}

public enum CopyStatus
{
    NotCopied,
    Queued,
    Copying,
    Copied,
    Verified,
    Failed,
    Skipped,
    Cancelled
}

public enum XmpStatus
{
    None,
    SidecarFound,
    SidecarWritten,
    Conflict
}

public enum ColorLabel
{
    Red,
    Yellow,
    Green,
    Blue,
    Purple
}

public enum ViewMode
{
    Grid,
    List,
    Gallery
}

public enum SortField
{
    Name,
    Kind,
    AddedDate,
    ModifiedDate,
    CreatedDate,
    LastOpenedDate,
    Size
}

public enum SortDirection
{
    Ascending,
    Descending
}

public enum CopyOrganizationRule
{
    CaptureDate,
    PreserveStructure,
    CameraModel,
    Rating
}

public enum CopyConflictPolicy
{
    AutoRename,
    SkipExisting,
    Overwrite
}

public enum CopyContentMode
{
    AllSupported,
    RawOnly
}

public enum CopyVerificationMode
{
    SizeOnly,
    Sha256
}

public enum AppAppearanceMode
{
    System,
    Light,
    Dark
}

public enum PreviewBackgroundTone
{
    System,
    Black,
    White,
    DarkGray,
    MiddleGray,
    LightGray
}

public enum ReviewMatteSize
{
    None,
    Small,
    Medium,
    Large
}

public enum FolderBrowserScale
{
    Small,
    Large
}

public enum HistogramPlacement
{
    Hidden,
    Floating,
    Inspector
}

public enum HistogramDisplayMode
{
    RgbAndLuminance,
    Rgb,
    Luminance,
    Red,
    Green,
    Blue
}

public enum HistogramCorner
{
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight
}

public enum CompositionOverlay
{
    Thirds,
    Center,
    Diagonals,
    GoldenRatio
}

public enum CompositionOverlayColor
{
    Gray,
    White,
    Black,
    Accent
}

public enum CropGuideRatio
{
    Hidden,
    Original,
    OneToOne,
    FourThree,
    ThreeTwo,
    SixteenNine,
    FiveFour,
    NineSixteen
}

public enum CropGuideOrientation
{
    Automatic,
    Landscape,
    Portrait
}

public enum CropGuideStyle
{
    Mask,
    Frame
}

public enum WaveformDirection
{
    HorizontalX,
    VerticalY
}

public enum WaveformChannelMode
{
    Luminance,
    Rgb,
    Red,
    Green,
    Blue
}

public enum CameraCardAction
{
    Off,
    Notify,
    SelectDcim,
    SelectAndScan
}

public enum AppLanguage
{
    System,
    English,
    Chinese,
    German
}

public enum ToolbarDisplayMode
{
    IconOnly,
    TextOnly,
    Both
}
