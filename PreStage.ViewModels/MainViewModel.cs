using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PreStage.Core.Imaging;
using PreStage.Core.Models;
using PreStage.Core.Services;

namespace PreStage.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly MediaScannerService _scanner = new();
    private readonly WorkspaceService _workspace = new();
    private readonly PreviewImageService _previewImage = new();
    private readonly PreviewPreheatService _preheatService = new();
    private readonly ThumbnailService _thumbnailService = new();
    private readonly CameraCardService _cameraCardService = new();
    private CopyService? _activeCopyService;
    private WorkspaceLibrary _library;

    public Dictionary<string, BitmapSource> ThumbnailCache { get; private set; } = new();
    private int _thumbnailVersion;
    public int ThumbnailVersion => _thumbnailVersion;

    [ObservableProperty]
    private string _sourcePath = "";

    partial void OnSourcePathChanged(string value)
    {
        SourceFolderTree = LoadFolderNodes(value);
    }

    [ObservableProperty]
    private string _targetPath = "";

    partial void OnTargetPathChanged(string value)
    {
        TargetFolderTree = LoadFolderNodes(value);
    }

    [ObservableProperty]
    private ViewMode _viewMode = ViewMode.Grid;

    [ObservableProperty]
    private SortRule _sortRule = SortRule.Default;

    [ObservableProperty]
    private bool _includeSubfolders;

    [ObservableProperty]
    private string _statusText = "Ready";

    partial void OnPreviewAspectRatioChanged(double value)
    {
        _cropAspectRatioDouble = 0;
        OnPropertyChanged(nameof(CropAspectRatioDouble));
    }

    [ObservableProperty]
    private string _visibleCountText = "";

    [ObservableProperty]
    private string _selectedCountText = "";

    [ObservableProperty]
    private MediaItem? _selectedItem;

    [ObservableProperty]
    private bool _isScanning;

    [ObservableProperty]
    private string _searchText = "";

    [ObservableProperty]
    private bool _isFilmstripCollapsed;

    [ObservableProperty]
    private bool _isPreheating;

    [ObservableProperty]
    private bool _isStackExpanded;

    [ObservableProperty]
    private CropGuideRatio _activeCropRatio = CropGuideRatio.Hidden;

    [ObservableProperty]
    private CropGuideStyle _cropStyle = CropGuideStyle.Mask;

    [ObservableProperty]
    private HashSet<CompositionOverlay> _activeGuides = [];

    [ObservableProperty]
    private List<CustomCropGuideRatio> _customCropRatios = [];

    [ObservableProperty]
    private Guid? _activeCustomCropRatioId;

    [ObservableProperty]
    private CropGuideOrientation _cropOrientation = CropGuideOrientation.Automatic;

    [ObservableProperty]
    private bool _guidesFollowCrop;

    [ObservableProperty]
    private CompositionOverlayColor _guideColor = CompositionOverlayColor.Gray;

    [ObservableProperty]
    private double _guideOpacity = 0.46;

    [ObservableProperty]
    private BitmapSource? _previewImageSource;

    [ObservableProperty]
    private int _previewPixelWidth;

    [ObservableProperty]
    private int _previewPixelHeight;

    [ObservableProperty]
    private double _previewAspectRatio = 1.0;

    [ObservableProperty]
    private double _containerWidth = 800;

    [ObservableProperty]
    private double _containerHeight = 600;

    [ObservableProperty]
    private double _dpiScale = 1.0;

    private double _cropAspectRatioDouble;
    public double CropAspectRatioDouble
    {
        get
        {
            if (_cropAspectRatioDouble > 0) return _cropAspectRatioDouble;
            if (ActiveCustomCropRatioId.HasValue)
            {
                var custom = CustomCropRatios.FirstOrDefault(r => r.Id == ActiveCustomCropRatioId.Value);
                if (custom != null)
                    return OrientedCropAspect(custom.Width, custom.Height);
            }

            return ActiveCropRatio switch
            {
                CropGuideRatio.Original => PreviewAspectRatio,
                CropGuideRatio.OneToOne => OrientedCropAspect(1.0, 1.0),
                CropGuideRatio.FourThree => OrientedCropAspect(4.0, 3.0),
                CropGuideRatio.ThreeTwo => OrientedCropAspect(3.0, 2.0),
                CropGuideRatio.SixteenNine => OrientedCropAspect(16.0, 9.0),
                CropGuideRatio.FiveFour => OrientedCropAspect(5.0, 4.0),
                CropGuideRatio.NineSixteen => OrientedCropAspect(9.0, 16.0),
                _ => 0
            };
        }
    }

    [ObservableProperty]
    private CopyOrganizationRule _copyRule = CopyOrganizationRule.CaptureDate;

    [ObservableProperty]
    private CopyConflictPolicy _copyConflictPolicy = CopyConflictPolicy.AutoRename;

    [ObservableProperty]
    private CopyContentMode _copyContentMode = CopyContentMode.AllSupported;

    [ObservableProperty]
    private CopyVerificationMode _copyVerificationMode = CopyVerificationMode.SizeOnly;

    [ObservableProperty]
    private bool _showCopySettings;

    [ObservableProperty]
    private bool _showCopyLog;

    [ObservableProperty]
    private CopyLogRecord? _lastCopyLog;

    [ObservableProperty]
    private CopyProgress _copyProgress = new();

    [ObservableProperty]
    private bool _isCopyRunning;

    [ObservableProperty]
    private string _copyStatusText = "";

    [ObservableProperty]
    private double _copyFraction;

    partial void OnCopyProgressChanged(CopyProgress value)
    {
        IsCopyRunning = value.IsRunning;
        CopyStatusText = value.Message;
        CopyFraction = value.Fraction;
    }

    [ObservableProperty]
    private int[]? _histogramLuminance;

    [ObservableProperty]
    private int[][]? _histogramChannel;

    [ObservableProperty]
    private int[][][]? _waveformData;

    [ObservableProperty]
    private int _waveformMaxValue;

    [ObservableProperty]
    private bool _showHistogram;

    [ObservableProperty]
    private HistogramPlacement _histogramPlacement = HistogramPlacement.Hidden;

    [ObservableProperty]
    private bool _showWaveform;

    [ObservableProperty]
    private HistogramPlacement _waveformPlacement = HistogramPlacement.Hidden;

    [ObservableProperty]
    private HistogramDisplayMode _histogramMode = HistogramDisplayMode.RgbAndLuminance;

    [ObservableProperty]
    private WaveformDirection _waveformDir = WaveformDirection.HorizontalX;

    [ObservableProperty]
    private WaveformChannelMode _waveformChannelMode = WaveformChannelMode.Luminance;

    [ObservableProperty]
    private AppAppearanceMode _appAppearance = AppAppearanceMode.System;

    [ObservableProperty]
    private PreviewBackgroundTone _previewBg = PreviewBackgroundTone.System;

    [ObservableProperty]
    private ReviewMatteSize _reviewMatte = ReviewMatteSize.None;

    [ObservableProperty]
    private bool _flippedHorizontally;

    [ObservableProperty]
    private bool _flippedVertically;

    [ObservableProperty]
    private ToolbarDisplayMode _toolbarDisplayMode = ToolbarDisplayMode.IconOnly;

    [ObservableProperty]
    private CameraCardAction _cameraCardAction = CameraCardAction.Notify;

    [ObservableProperty]
    private List<FolderNode> _sourceFolderTree = [];

    [ObservableProperty]
    private List<FolderNode> _targetFolderTree = [];

    public ObservableCollection<MediaItem> MediaItems => _mediaItems;
    private ObservableCollection<MediaItem> _mediaItems = [];
    public ObservableCollection<FilmstripItem> FilmstripItems => _filmstripItems;
    private ObservableCollection<FilmstripItem> _filmstripItems = [];
    public ObservableCollection<CameraCardInfo> DetectedCards { get; } = [];
    public List<MediaItem> RawItems { get; private set; } = [];

    public FilterState Filter { get; } = new();
    public PanelLayout PanelLayout { get; } = new();
    public WorkspacePreset ActivePreset { get; private set; } = WorkspacePreset.Default;

    public MainViewModel()
    {
        _library = _workspace.Load();
        ActivePreset = _workspace.GetActivePreset(_library);
        RestoreFromPreset(ActivePreset);
        _cameraCardService.CardsChanged += OnCameraCardsChanged;
        _cameraCardService.CardDetected += OnCameraCardDetected;
        ReplaceDetectedCards(_cameraCardService.Start());
    }

    private void OnCameraCardsChanged(IReadOnlyList<CameraCardInfo> cards)
    {
        System.Windows.Application.Current?.Dispatcher.Invoke(() => ReplaceDetectedCards(cards));
    }

    private void OnCameraCardDetected(CameraCardInfo card)
    {
        System.Windows.Application.Current?.Dispatcher.Invoke(async () =>
        {
            StatusText = $"Camera card detected: {card.DriveLabel} ({card.RootPath})";
            if (CameraCardAction == CameraCardAction.Off)
                return;

            var path = card.DcimPath ?? card.RootPath;
            if (CameraCardAction is CameraCardAction.SelectDcim or CameraCardAction.SelectAndScan)
            {
                SourcePath = path;
                await SaveWorkspaceAsync();
            }

            if (CameraCardAction == CameraCardAction.SelectAndScan)
                await ScanSourceAsync();
        });
    }

    private void ReplaceDetectedCards(IReadOnlyList<CameraCardInfo> cards)
    {
        DetectedCards.Clear();
        foreach (var card in cards)
            DetectedCards.Add(card);
    }

    private static List<FolderNode> LoadFolderNodes(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !Directory.Exists(path))
            return [];

        try
        {
            return Directory.EnumerateDirectories(path)
                .Take(200)
                .Select(dir => new FolderNode
                {
                    Name = Path.GetFileName(dir),
                    FullPath = dir,
                    HasUnloadedChildren = HasChildDirectory(dir)
                })
                .ToList();
        }
        catch
        {
            return [];
        }
    }

    private static bool HasChildDirectory(string path)
    {
        try
        {
            return Directory.EnumerateDirectories(path).Any();
        }
        catch
        {
            return false;
        }
    }

    private double OrientedCropAspect(double width, double height)
    {
        var baseRatio = width / height;
        if (CropOrientation == CropGuideOrientation.Landscape)
            return Math.Max(baseRatio, 1.0 / baseRatio);
        if (CropOrientation == CropGuideOrientation.Portrait)
            return Math.Min(baseRatio, 1.0 / baseRatio);

        var current = PreviewAspectRatio > 0 ? PreviewAspectRatio : baseRatio;
        var isPortrait = current < 1.0;
        if (isPortrait && baseRatio > 1.0) return 1.0 / baseRatio;
        if (!isPortrait && baseRatio < 1.0) return 1.0 / baseRatio;
        return baseRatio;
    }

    private void RestoreFromPreset(WorkspacePreset preset)
    {
        SourcePath = preset.LocalSourcePath ?? "";
        TargetPath = preset.LocalTargetPath ?? "";
        ViewMode = preset.ViewMode;
        SortRule = preset.SortRule;
        IncludeSubfolders = preset.IncludeSourceSubfolders;
        CopyRule = preset.CopyRule;
        CopyConflictPolicy = preset.CopyConflictPolicy;
        CopyContentMode = preset.CopyContentMode;
        CopyVerificationMode = preset.CopyVerificationMode;
        CameraCardAction = preset.CameraCardAction;

        HistogramPlacement = preset.PanelLayout.HistogramPlacement;
        WaveformPlacement = preset.PanelLayout.WaveformPlacement;
        HistogramMode = preset.PanelLayout.HistogramDisplayMode;
        WaveformDir = preset.PanelLayout.WaveformDirection;
        WaveformChannelMode = preset.PanelLayout.WaveformChannelMode;
        ActiveGuides = preset.PanelLayout.CompositionOverlays;
        GuideColor = preset.PanelLayout.CompositionOverlayColor;
        GuideOpacity = preset.PanelLayout.CompositionOverlayOpacity;
        GuidesFollowCrop = preset.PanelLayout.CompositionGuidesFollowCrop;
        ActiveCropRatio = preset.PanelLayout.CropGuideRatio;
        CropStyle = preset.PanelLayout.CropGuideStyle;
        CropOrientation = preset.PanelLayout.CropGuideOrientation;
        CustomCropRatios = preset.PanelLayout.CustomCropGuideRatios;
        ActiveCustomCropRatioId = preset.PanelLayout.ActiveCustomCropGuideRatioId;
        AppAppearance = preset.PanelLayout.AppAppearance;
        PreviewBg = preset.PanelLayout.PreviewBackground;
        ReviewMatte = preset.PanelLayout.ReviewMatteSize;

        ShowHistogram = HistogramPlacement == HistogramPlacement.Floating;
        ShowWaveform = WaveformPlacement == HistogramPlacement.Floating;

        if (!string.IsNullOrEmpty(SourcePath))
            _ = ScanSourceAsync();
    }

    [RelayCommand]
    private async Task SelectSourceFolderAsync()
    {
        try
        {
            var dialog = new System.Windows.Forms.FolderBrowserDialog
            {
                Description = "Select source folder"
            };

            if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                SourcePath = dialog.SelectedPath;
                await SaveWorkspaceAsync();
                await ScanSourceAsync();
            }
        }
        catch (Exception ex)
        {
            StatusText = $"Error: {ex.Message}";
        }
    }

    [RelayCommand]
    private async Task SelectTargetFolderAsync()
    {
        try
        {
            var dialog = new System.Windows.Forms.FolderBrowserDialog
            {
                Description = "Select target folder"
            };

            if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                TargetPath = dialog.SelectedPath;
                await SaveWorkspaceAsync();
            }
        }
        catch (Exception ex)
        {
            StatusText = $"Error: {ex.Message}";
        }
    }

    [RelayCommand]
    private async Task ScanSourceAsync()
    {
        if (string.IsNullOrEmpty(SourcePath)) return;

        IsScanning = true;
        StatusText = "Scanning...";

        try
        {
            RawItems = await Task.Run(() => _scanner.QuickScanWithPairing(SourcePath, IncludeSubfolders));
            _preheatService.ClearCache();
            ApplyFiltersAndSort();
            _ = LoadThumbnailsAsync();
        }
        catch (Exception ex)
        {
            StatusText = $"Scan error: {ex.Message}";
        }
        finally
        {
            IsScanning = false;
            UpdateStatus();
        }
    }

    private async Task LoadThumbnailsAsync()
    {
        var items = SelectedItem != null ? new List<MediaItem> { SelectedItem } : [];
        if (items.Count == 0)
        {
            StatusText = "Select files before copying.";
            return;
        }

        StatusText = "Loading thumbnails...";

        await Task.Run(() =>
        {
            var batch = new List<(string url, BitmapSource source)>();
            foreach (var item in items)
            {
                try
                {
                    var bmp = _thumbnailService.GetThumbnail(item, 256, 256);
                    if (bmp == null) continue;

                    var source = ConvertToBitmapSource(bmp);
                    bmp.Dispose();
                    batch.Add((item.Url, source));
                }
                catch
                {
                }
            }

            System.Windows.Application.Current?.Dispatcher.BeginInvoke(() =>
            {
                var newCache = new Dictionary<string, BitmapSource>(ThumbnailCache);
                foreach (var (url, source) in batch)
                    newCache[url] = source;
                ThumbnailCache = newCache;
                _thumbnailVersion++;
                OnPropertyChanged(nameof(ThumbnailCache));
                OnPropertyChanged(nameof(ThumbnailVersion));
                StatusText = $"Showing {MediaItems.Count} of {RawItems.Count} items";
            });
        });
    }

    private static BitmapSource ConvertToBitmapSource(System.Drawing.Bitmap bitmap)
    {
        var rect = new System.Drawing.Rectangle(0, 0, bitmap.Width, bitmap.Height);
        var data = bitmap.LockBits(rect, System.Drawing.Imaging.ImageLockMode.ReadOnly, bitmap.PixelFormat);

        try
        {
            var source = BitmapSource.Create(
                data.Width, data.Height, 96, 96,
                System.Windows.Media.PixelFormats.Bgra32, null,
                data.Scan0, data.Stride * data.Height, data.Stride);
            source.Freeze();
            return source;
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

    [RelayCommand]
    private void Refresh()
    {
        _ = ScanSourceAsync();
    }

    [RelayCommand]
    private async Task SelectSourcePathAsync(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !Directory.Exists(path)) return;
        SourcePath = path;
        await SaveWorkspaceAsync();
        await ScanSourceAsync();
    }

    [RelayCommand]
    private async Task SelectTargetPathAsync(string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return;
        TargetPath = path;
        await SaveWorkspaceAsync();
    }

    [RelayCommand]
    private async Task OpenCameraCardAsync(CameraCardInfo? card)
    {
        if (card == null) return;
        var path = card.DcimPath ?? card.RootPath;
        SourcePath = path;
        await SaveWorkspaceAsync();
        await ScanSourceAsync();
    }

    [RelayCommand]
    private void EjectCard(CameraCardInfo? card)
    {
        if (card == null) return;
        var ok = CameraCardService.TryEject(card.RootPath);
        StatusText = ok
            ? $"Ejected {card.DriveLabel}"
            : "Safe eject is not available yet; use Windows 'Safely Remove Hardware'.";
    }

    private void ApplyFiltersAndSort()
    {
        var filtered = RawItems.Where(Filter.Includes).ToList();

        if (!IsStackExpanded)
            filtered = new MediaPairingService().CollapsePairs(filtered);

        filtered = SortRule.Field switch
        {
            SortField.Name => SortRule.Direction == SortDirection.Ascending
                ? filtered.OrderBy(i => i.Filename).ToList()
                : filtered.OrderByDescending(i => i.Filename).ToList(),
            SortField.Kind => SortRule.Direction == SortDirection.Ascending
                ? filtered.OrderBy(i => i.MediaType).ToList()
                : filtered.OrderByDescending(i => i.MediaType).ToList(),
            SortField.ModifiedDate => SortRule.Direction == SortDirection.Ascending
                ? filtered.OrderBy(i => i.ModifiedDate ?? DateTime.MinValue).ToList()
                : filtered.OrderByDescending(i => i.ModifiedDate ?? DateTime.MinValue).ToList(),
            SortField.CreatedDate => SortRule.Direction == SortDirection.Ascending
                ? filtered.OrderBy(i => i.CreatedDate ?? DateTime.MinValue).ToList()
                : filtered.OrderByDescending(i => i.CreatedDate ?? DateTime.MinValue).ToList(),
            SortField.LastOpenedDate => SortRule.Direction == SortDirection.Ascending
                ? filtered.OrderBy(i => i.LastOpenedDate ?? DateTime.MinValue).ToList()
                : filtered.OrderByDescending(i => i.LastOpenedDate ?? DateTime.MinValue).ToList(),
            SortField.Size => SortRule.Direction == SortDirection.Ascending
                ? filtered.OrderBy(i => i.FileSize).ToList()
                : filtered.OrderByDescending(i => i.FileSize).ToList(),
            _ => SortRule.Direction == SortDirection.Ascending
                ? filtered.OrderBy(i => i.AddedDate ?? DateTime.MinValue).ToList()
                : filtered.OrderByDescending(i => i.AddedDate ?? DateTime.MinValue).ToList()
        };

        _mediaItems = new ObservableCollection<MediaItem>(filtered);
        _filmstripItems = new ObservableCollection<FilmstripItem>(filtered.Select(i => new FilmstripItem(i)));
        OnPropertyChanged(nameof(MediaItems));
        OnPropertyChanged(nameof(FilmstripItems));

        UpdateStatus();
    }

    [RelayCommand]
    private void SetViewMode(string mode)
    {
        ViewMode = mode switch
        {
            "Grid" => ViewMode.Grid,
            "List" => ViewMode.List,
            "Gallery" => ViewMode.Gallery,
            _ => ViewMode.Grid
        };
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetSortField(string field)
    {
        if (Enum.TryParse<SortField>(field, out var sf))
        {
            if (SortRule.Field == sf)
                SortRule = new SortRule(sf, SortRule.Direction == SortDirection.Ascending
                    ? SortDirection.Descending : SortDirection.Ascending);
            else
                SortRule = new SortRule(sf, SortDirection.Ascending);
            ApplyFiltersAndSort();
            _ = SaveWorkspaceAsync();
        }
    }

    [RelayCommand]
    private void ToggleSortDirection()
    {
        SortRule = new SortRule(SortRule.Field,
            SortRule.Direction == SortDirection.Ascending
                ? SortDirection.Descending : SortDirection.Ascending);
        ApplyFiltersAndSort();
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void ToggleSubfolders()
    {
        IncludeSubfolders = !IncludeSubfolders;
        _ = SaveWorkspaceAsync();
    }

    private CancellationTokenSource? _searchCts;

    partial void OnSearchTextChanged(string value)
    {
        _searchCts?.Cancel();
        _searchCts = new CancellationTokenSource();
        var token = _searchCts.Token;

        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(300, token);
                Filter.SearchText = value;
                System.Windows.Application.Current?.Dispatcher.Invoke(ApplyFiltersAndSort);
            }
            catch (OperationCanceledException)
            {
            }
        });
    }

    [ObservableProperty]
    private bool _hasItems;

    [ObservableProperty]
    private int _minimumRating;

    partial void OnMinimumRatingChanged(int value)
    {
        Filter.MinimumRating = value;
        ApplyFiltersAndSort();
    }

    [ObservableProperty]
    private ColorLabel? _filterColorLabel;

    partial void OnFilterColorLabelChanged(ColorLabel? value)
    {
        Filter.ColorLabel = value;
        ApplyFiltersAndSort();
    }

    [ObservableProperty]
    private PickState? _filterPickState;

    partial void OnFilterPickStateChanged(PickState? value)
    {
        Filter.PickState = value;
        ApplyFiltersAndSort();
    }

    private void UpdateStatus()
    {
        VisibleCountText = $"{MediaItems.Count} items";
        HasItems = MediaItems.Count > 0;
        StatusText = HasItems
            ? $"Showing {MediaItems.Count} of {RawItems.Count} items"
            : "No items";
    }

    partial void OnSelectedItemChanged(MediaItem? value)
    {
        SelectedCountText = value != null ? "1 selected" : "";
        if (value != null)
        {
            if (ViewMode == ViewMode.Gallery)
            {
                _ = LoadPreviewAsync(value);
                _ = PreheatAroundAsync(value);
            }

            if (ShowHistogram || HistogramPlacement == HistogramPlacement.Inspector)
                _ = Task.Run(() => ComputeHistogram(value));

            if (ShowWaveform || WaveformPlacement == HistogramPlacement.Inspector)
                _ = Task.Run(() => ComputeWaveform(value));
        }
    }

    private async Task PreheatAroundAsync(MediaItem center)
    {
        IsPreheating = true;
        try
        {
            var items = MediaItems.ToList();
            await Task.Run(() => _preheatService.PreheatAsync(center, items, 3));
        }
        catch
        {
        }
        finally
        {
            IsPreheating = false;
        }
    }

    [RelayCommand]
    private async Task LoadPreviewAsync(MediaItem item)
    {
        try
        {
            var result = _preheatService.TryGetCached(item.Url)
                ?? await Task.Run(() => _previewImage.LoadPreview(item.Url, 2560, 1440));

            if (result != null)
            {
                PreviewImageSource = result.Bitmap;
                PreviewPixelWidth = result.PixelWidth;
                PreviewPixelHeight = result.PixelHeight;
                PreviewAspectRatio = result.AspectRatio;
            }
        }
        catch (Exception ex)
        {
            StatusText = $"Preview error: {ex.Message}";
        }
    }

    [RelayCommand]
    private void NavigateGallery(string direction)
    {
        if (SelectedItem == null || MediaItems.Count == 0) return;
        var idx = MediaItems.IndexOf(SelectedItem);
        if (idx < 0) return;

        idx = direction switch
        {
            "Next" => Math.Min(idx + 1, MediaItems.Count - 1),
            "Prev" => Math.Max(idx - 1, 0),
            _ => idx
        };

        SelectedItem = MediaItems[idx];
    }

    [RelayCommand]
    private void ToggleFilmstrip()
    {
        IsFilmstripCollapsed = !IsFilmstripCollapsed;
    }

    [RelayCommand]
    private void ToggleStackExpansion()
    {
        IsStackExpanded = !IsStackExpanded;
        ApplyFiltersAndSort();
    }

    [RelayCommand]
    private void SetCropRatio(string ratio)
    {
        ActiveCustomCropRatioId = null;
        ActiveCropRatio = ratio switch
        {
            "Hidden" => CropGuideRatio.Hidden,
            "Original" => CropGuideRatio.Original,
            "1:1" => CropGuideRatio.OneToOne,
            "4:3" => CropGuideRatio.FourThree,
            "3:2" => CropGuideRatio.ThreeTwo,
            "16:9" => CropGuideRatio.SixteenNine,
            "5:4" => CropGuideRatio.FiveFour,
            "9:16" => CropGuideRatio.NineSixteen,
            _ => CropGuideRatio.Hidden
        };
        _cropAspectRatioDouble = 0;
        OnPropertyChanged(nameof(CropAspectRatioDouble));
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void AddCustomCropRatio()
    {
        if (CustomCropRatios.Count >= CustomCropGuideRatio.MaximumSavedCount) return;
        CustomCropRatios = [.. CustomCropRatios, new CustomCropGuideRatio($"Custom {CustomCropRatios.Count + 1}", 16.0, 9.0)];
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void RemoveCustomCropRatio(string idStr)
    {
        if (!Guid.TryParse(idStr, out var id)) return;
        CustomCropRatios = CustomCropRatios.Where(r => r.Id != id).ToList();
        if (ActiveCustomCropRatioId == id)
            ActiveCustomCropRatioId = null;
        _cropAspectRatioDouble = 0;
        OnPropertyChanged(nameof(CropAspectRatioDouble));
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SelectCustomCropRatio(string idStr)
    {
        if (!Guid.TryParse(idStr, out var id)) return;
        if (CustomCropRatios.All(r => r.Id != id)) return;
        ActiveCustomCropRatioId = id;
        ActiveCropRatio = CropGuideRatio.Hidden;
        _cropAspectRatioDouble = 0;
        OnPropertyChanged(nameof(CropAspectRatioDouble));
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetCropOrientation(string orientation)
    {
        CropOrientation = orientation switch
        {
            "Landscape" => CropGuideOrientation.Landscape,
            "Portrait" => CropGuideOrientation.Portrait,
            _ => CropGuideOrientation.Automatic
        };
        _cropAspectRatioDouble = 0;
        OnPropertyChanged(nameof(CropAspectRatioDouble));
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void ToggleGuide(string guide)
    {
        if (Enum.TryParse<CompositionOverlay>(guide, out var g))
        {
            if (!ActiveGuides.Remove(g))
                ActiveGuides.Add(g);
            OnPropertyChanged(nameof(ActiveGuides));
            _ = SaveWorkspaceAsync();
        }
    }

    [RelayCommand]
    private void SetGuidesFollowCrop(string followStr)
    {
        GuidesFollowCrop = followStr == "True";
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetGuideColor(string color)
    {
        GuideColor = color switch
        {
            "White" => CompositionOverlayColor.White,
            "Black" => CompositionOverlayColor.Black,
            "Accent" => CompositionOverlayColor.Accent,
            _ => CompositionOverlayColor.Gray
        };
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetGuideOpacity(string opacityStr)
    {
        if (double.TryParse(opacityStr, out var val))
        {
            GuideOpacity = Math.Clamp(val, 0.1, 1.0);
            _ = SaveWorkspaceAsync();
        }
    }

    [RelayCommand]
    private void ToggleCropStyle()
    {
        CropStyle = CropStyle == CropGuideStyle.Mask
            ? CropGuideStyle.Frame : CropGuideStyle.Mask;
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void NavigateToPaired()
    {
        if (SelectedItem == null) return;
        var paired = new MediaPairingService().GetPairedItem(SelectedItem, RawItems);
        if (paired == null) return;
        var visible = MediaItems.FirstOrDefault(i => string.Equals(i.Url, paired.Url, StringComparison.OrdinalIgnoreCase));
        if (visible != null)
            SelectedItem = visible;
    }

    [RelayCommand]
    private void SetRating(string ratingStr)
    {
        if (SelectedItem == null) return;
        if (!int.TryParse(ratingStr, out var rating)) return;
        SelectedItem.Rating = Math.Clamp(rating, 0, 5);
        ApplyFiltersAndSort();
        WriteXmpSidecar(SelectedItem);
    }

    [RelayCommand]
    private void SetPickState(string state)
    {
        if (SelectedItem == null) return;
        SelectedItem.PickState = state switch
        {
            "Pick" => PickState.Picked,
            "Reject" => PickState.Rejected,
            _ => PickState.Unmarked
        };
        WriteXmpSidecar(SelectedItem);
    }

    [RelayCommand]
    private void SetColorLabel(string label)
    {
        if (SelectedItem == null) return;
        SelectedItem.ColorLabel = Enum.TryParse<ColorLabel>(label, out var cl)
            ? cl : null;
        WriteXmpSidecar(SelectedItem);
    }

    [RelayCommand]
    private void EnrichAllMetadata()
    {
        if (RawItems.Count == 0) return;
        StatusText = "Loading metadata...";

        Task.Run(() =>
        {
            try
            {
                var cts = new CancellationTokenSource();
                _scanner.EnrichMetadata(RawItems, _ =>
                {
                }, cts.Token);

                System.Windows.Application.Current?.Dispatcher.Invoke(() =>
                {
                    ApplyFiltersAndSort();
                    StatusText = "Metadata loaded";
                });
            }
            catch (Exception ex)
            {
                System.Windows.Application.Current?.Dispatcher.Invoke(() =>
                {
                    StatusText = $"Metadata error: {ex.Message}";
                });
            }
        });
    }

    [RelayCommand]
    private void ShareItems()
    {
    }

    [RelayCommand]
    private void OpenItems()
    {
        if (SelectedItem == null) return;
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = SelectedItem.Url,
                UseShellExecute = true
            });
        }
        catch
        {
        }
    }

    [RelayCommand]
    private void RevealInExplorer()
    {
        if (SelectedItem == null) return;
        try
        {
            System.Diagnostics.Process.Start("explorer.exe", $"/select,\"{SelectedItem.Url}\"");
        }
        catch
        {
        }
    }

    [RelayCommand]
    private void RotateLeft()
    {
    }

    [RelayCommand]
    private void RotateRight()
    {
    }

    [RelayCommand]
    private void FlipHorizontal()
    {
        FlippedHorizontally = !FlippedHorizontally;
    }

    [RelayCommand]
    private void FlipVertical()
    {
        FlippedVertically = !FlippedVertically;
    }

    private void WriteXmpSidecar(MediaItem item)
    {
        var xmpService = new XmpService();
        var sidecarPath = XmpService.GetSidecarPath(item.Url);

        XmpData? existing = null;
        if (File.Exists(sidecarPath))
        {
            existing = xmpService.Read(sidecarPath);
        }

        var data = existing ?? new XmpData();
        data.Rating = item.Rating;
        data.Label = item.ColorLabel?.ToString();
        data.PickState = item.PickState;
        data.CreatorTool ??= "PreStage";
        data.RawDocument ??= existing?.RawDocument;

        try
        {
            xmpService.Write(sidecarPath, data);
            item.XmpStatus = XmpStatus.SidecarWritten;

            if (!string.IsNullOrEmpty(item.PairedAssetKey))
            {
                SyncPairedReviewState(item);
                var partnerPath = XmpService.GetSidecarPath(item.PairedAssetKey);
                xmpService.Write(partnerPath, data);
            }
        }
        catch
        {
            item.XmpStatus = XmpStatus.Conflict;
        }
    }

    private void SyncPairedReviewState(MediaItem item)
    {
        var partner = RawItems.FirstOrDefault(i =>
            string.Equals(i.Url, item.PairedAssetKey, StringComparison.OrdinalIgnoreCase));
        if (partner == null) return;

        partner.Rating = item.Rating;
        partner.ColorLabel = item.ColorLabel;
        partner.PickState = item.PickState;
        partner.XmpStatus = XmpStatus.SidecarWritten;
    }

    [RelayCommand]
    private async Task ScanWithPairingAsync()
    {
        if (string.IsNullOrEmpty(SourcePath)) return;

        IsScanning = true;
        StatusText = "Scanning with pairing...";

        try
        {
            RawItems = await Task.Run(() => _scanner.QuickScanWithPairing(SourcePath, IncludeSubfolders));
            ApplyFiltersAndSort();
        }
        catch (Exception ex)
        {
            StatusText = $"Scan error: {ex.Message}";
        }
        finally
        {
            IsScanning = false;
            UpdateStatus();
        }
    }

    [RelayCommand]
    private void ToggleCopySettings()
    {
        ShowCopySettings = !ShowCopySettings;
    }

    [RelayCommand]
    private void ToggleCopyLog()
    {
        ShowCopyLog = !ShowCopyLog;
    }

    [RelayCommand]
    private async Task StartCopyAsync()
    {
        if (string.IsNullOrEmpty(TargetPath) || RawItems.Count == 0) return;
        ShowCopySettings = false;

        var items = MediaItems.ToList();
        if (items.Count == 0) return;

        _activeCopyService = new CopyService();
        _activeCopyService.OnLogMessage += message =>
        {
            System.Windows.Application.Current?.Dispatcher.Invoke(() =>
            {
                CopyStatusText = message;
            });
        };
        CopyProgress = _activeCopyService.Progress;
        IsCopyRunning = true;

        var timer = new System.Timers.Timer(100);
        timer.Elapsed += (_, _) =>
        {
            System.Windows.Application.Current?.Dispatcher.Invoke(() =>
            {
                CopyFraction = _activeCopyService.Progress.Fraction;
                CopyStatusText = _activeCopyService.Progress.Message;
            });
        };
        timer.Start();

        try
        {
            var log = await Task.Run(() =>
                _activeCopyService.CopyAsync(items, TargetPath,
                    CopyRule, CopyConflictPolicy, CopyContentMode, CopyVerificationMode,
                    sourceRoot: SourcePath));

            LastCopyLog = log;
            StatusText = $"Copy finished: {log.Entries.Count(e => e.Status == CopyStatus.Verified)} files";
        }
        catch (Exception ex)
        {
            StatusText = $"Copy error: {ex.Message}";
        }
        finally
        {
            timer.Stop();
            timer.Dispose();
            CopyProgress = _activeCopyService.Progress;
            IsCopyRunning = _activeCopyService.Progress.IsRunning;
        }
    }

    [RelayCommand]
    private void PauseCopy()
    {
        _activeCopyService?.Pause();
    }

    [RelayCommand]
    private void ResumeCopy()
    {
        _activeCopyService?.Resume();
    }

    [RelayCommand]
    private void CancelCopy()
    {
        _activeCopyService?.Cancel();
    }

    [RelayCommand]
    private void ToggleHistogram()
    {
        if (HistogramPlacement == HistogramPlacement.Hidden)
        {
            HistogramPlacement = HistogramPlacement.Floating;
            ShowHistogram = true;
        }
        else
        {
            HistogramPlacement = HistogramPlacement.Hidden;
            ShowHistogram = false;
        }

        if (HistogramPlacement != HistogramPlacement.Hidden && SelectedItem != null)
            ComputeHistogram(SelectedItem);
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void ToggleWaveform()
    {
        if (WaveformPlacement == HistogramPlacement.Hidden)
        {
            WaveformPlacement = HistogramPlacement.Floating;
            ShowWaveform = true;
        }
        else
        {
            WaveformPlacement = HistogramPlacement.Hidden;
            ShowWaveform = false;
        }

        if (WaveformPlacement != HistogramPlacement.Hidden && SelectedItem != null)
            ComputeWaveform(SelectedItem);
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetHistogramPlacement(string mode)
    {
        HistogramPlacement = Enum.TryParse<HistogramPlacement>(mode, out var placement)
            ? placement : HistogramPlacement.Floating;
        ShowHistogram = HistogramPlacement == HistogramPlacement.Floating;
        if (HistogramPlacement != HistogramPlacement.Hidden && SelectedItem != null)
            ComputeHistogram(SelectedItem);
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetWaveformPlacement(string mode)
    {
        WaveformPlacement = Enum.TryParse<HistogramPlacement>(mode, out var placement)
            ? placement : HistogramPlacement.Floating;
        ShowWaveform = WaveformPlacement == HistogramPlacement.Floating;
        if (WaveformPlacement != HistogramPlacement.Hidden && SelectedItem != null)
            ComputeWaveform(SelectedItem);
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetHistogramMode(string mode)
    {
        HistogramMode = Enum.TryParse<HistogramDisplayMode>(mode, out var m)
            ? m : HistogramDisplayMode.RgbAndLuminance;
        if (HistogramPlacement != HistogramPlacement.Hidden && SelectedItem != null)
            ComputeHistogram(SelectedItem);
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void SetWaveformChannelMode(string mode)
    {
        WaveformChannelMode = Enum.TryParse<WaveformChannelMode>(mode, out var m)
            ? m : WaveformChannelMode.Luminance;
        if (WaveformPlacement != HistogramPlacement.Hidden && SelectedItem != null)
            ComputeWaveform(SelectedItem);
        _ = SaveWorkspaceAsync();
    }

    [RelayCommand]
    private void ToggleWaveformDirection()
    {
        WaveformDir = WaveformDir == WaveformDirection.HorizontalX
            ? WaveformDirection.VerticalY : WaveformDirection.HorizontalX;
        if (WaveformPlacement != HistogramPlacement.Hidden && SelectedItem != null)
            ComputeWaveform(SelectedItem);
        _ = SaveWorkspaceAsync();
    }

    private void ComputeHistogram(MediaItem item)
    {
        var analysis = new ImageAnalysisService();
        var buffer = analysis.GetRgbaBuffer(item.Url);
        if (buffer == null) return;

        var hs = new HistogramService();
        var data = hs.Compute(buffer);

        System.Windows.Application.Current?.Dispatcher.Invoke(() =>
        {
            HistogramLuminance = data.Luminance;
            HistogramChannel = [data.Red, data.Green, data.Blue, data.Luminance];
        });
    }

    private void ComputeWaveform(MediaItem item)
    {
        var analysis = new ImageAnalysisService();
        var buffer = analysis.GetRgbaBuffer(item.Url);
        if (buffer == null) return;

        var ws = new WaveformService();
        var data = WaveformDir == WaveformDirection.HorizontalX
            ? ws.ComputeX(buffer)
            : ws.ComputeY(buffer);

        System.Windows.Application.Current?.Dispatcher.Invoke(() =>
        {
            WaveformData = data.Pixels;
            WaveformMaxValue = data.MaxValue;
        });
    }

    [RelayCommand]
    private void SetAppAppearance(string mode)
    {
        AppAppearance = Enum.TryParse<AppAppearanceMode>(mode, out var a) ? a : AppAppearanceMode.System;
    }

    [RelayCommand]
    private void SetPreviewBg(string tone)
    {
        PreviewBg = Enum.TryParse<PreviewBackgroundTone>(tone, out var t) ? t : PreviewBackgroundTone.System;
    }

    [RelayCommand]
    private void SetReviewMatte(string size)
    {
        ReviewMatte = Enum.TryParse<ReviewMatteSize>(size, out var s) ? s : ReviewMatteSize.None;
    }

    private readonly ProxyGenerationService _proxyService = new();
    private readonly BatchRenameService _renameService = new();
    private ProxyGenerationService? _activeProxyService;

    [ObservableProperty]
    private string _proxyProgressText = "";

    [ObservableProperty]
    private string _renamePattern = "{original}_{index}";

    public ObservableCollection<RenamePreviewEntry> RenamePreviewList { get; } = [];

    [RelayCommand]
    private async Task GenerateProxiesAsync()
    {
        if (string.IsNullOrEmpty(SourcePath) || RawItems.Count == 0) return;

        _activeProxyService = new ProxyGenerationService();
        ProxyProgressText = "Starting proxy generation...";

        var items = RawItems.ToList();

        var timer = new System.Timers.Timer(200);
        timer.Elapsed += (_, _) =>
        {
            System.Windows.Application.Current?.Dispatcher.Invoke(() =>
            {
                if (_activeProxyService != null)
                    ProxyProgressText = _activeProxyService.Progress.Message;
            });
        };
        timer.Start();

        try
        {
            await Task.Run(() =>
                _activeProxyService.GenerateProxiesAsync(SourcePath, items));
        }
        catch (Exception ex)
        {
            ProxyProgressText = $"Proxy error: {ex.Message}";
        }
        finally
        {
            timer.Stop();
            timer.Dispose();
            ProxyProgressText = _activeProxyService.Progress.Message;
            _activeProxyService = null;
        }
    }

    [RelayCommand]
    private void BatchRenamePreview()
    {
        if (string.IsNullOrEmpty(RenamePattern) || RawItems.Count == 0) return;

        var items = MediaItems.ToList();
        var previews = _renameService.Preview(items, RenamePattern);
        RenamePreviewList.Clear();
        foreach (var entry in previews)
            RenamePreviewList.Add(entry);

        StatusText = $"Preview: {previews.Count} items, " +
            $"{previews.Count(p => p.HasConflict)} conflicts";
    }

    [RelayCommand]
    private void BatchRenameApply()
    {
        if (string.IsNullOrEmpty(RenamePattern) || RawItems.Count == 0) return;

        var items = MediaItems.ToList();
        var result = _renameService.Apply(items, RenamePattern);

        if (result.HasConflicts)
        {
            StatusText = result.Message;
            return;
        }

        StatusText = result.Message;
        _ = ScanSourceAsync();
    }

    private async Task SaveWorkspaceAsync()
    {
        try
        {
            ActivePreset = new WorkspacePreset
            {
                Id = ActivePreset.Id,
                Name = ActivePreset.Name,
                PanelLayout = CapturePanelLayout(),
                ViewMode = ViewMode,
                FilterState = Filter,
                SortRule = SortRule,
                LocalSourcePath = SourcePath,
                LocalTargetPath = TargetPath,
                CopyRule = CopyRule,
                CopyConflictPolicy = CopyConflictPolicy,
                CopyContentMode = CopyContentMode,
                CopyVerificationMode = CopyVerificationMode,
                IncludeSourceSubfolders = IncludeSubfolders,
                CameraCardAction = CameraCardAction
            };

            _workspace.ApplyPreset(_library, ActivePreset);
            await Task.Run(() => _workspace.Save(_library));
        }
        catch
        {
        }
    }

    private PanelLayout CapturePanelLayout()
    {
        PanelLayout.HistogramPlacement = HistogramPlacement;
        PanelLayout.WaveformPlacement = WaveformPlacement;
        PanelLayout.HistogramDisplayMode = HistogramMode;
        PanelLayout.WaveformDirection = WaveformDir;
        PanelLayout.WaveformChannelMode = WaveformChannelMode;
        PanelLayout.CompositionOverlays = ActiveGuides;
        PanelLayout.CompositionOverlayColor = GuideColor;
        PanelLayout.CompositionOverlayOpacity = GuideOpacity;
        PanelLayout.CompositionGuidesFollowCrop = GuidesFollowCrop;
        PanelLayout.CropGuideRatio = ActiveCropRatio;
        PanelLayout.CropGuideStyle = CropStyle;
        PanelLayout.CropGuideOrientation = CropOrientation;
        PanelLayout.CustomCropGuideRatios = CustomCropRatios;
        PanelLayout.ActiveCustomCropGuideRatioId = ActiveCustomCropRatioId;
        PanelLayout.AppAppearance = AppAppearance;
        PanelLayout.PreviewBackground = PreviewBg;
        PanelLayout.ReviewMatteSize = ReviewMatte;
        return PanelLayout;
    }
}
