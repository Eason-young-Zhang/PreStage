using MetadataExtractor;
using MetadataExtractor.Formats.Exif;
using MetadataExtractor.Formats.Xmp;
using MetadataExtractor.Formats.Jpeg;
using MetadataExtractor.Formats.Iptc;
using MetadataExtractor.Formats.FileSystem;
using MetadataExtractor.Formats.Icc;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class MetadataService
{
    private static readonly MetadataDiskCache _cache = MetadataDiskCache.Instance;

    public void Enrich(MediaItem item)
    {
        try
        {
            var cacheEntry = _cache.TryGet(item.Url);
            if (cacheEntry != null)
            {
                PopulateFromCache(item, cacheEntry);
                EnrichSidecar(item);
                return;
            }

            IReadOnlyList<MetadataExtractor.Directory> directories = [];
            try
            {
                directories = ImageMetadataReader.ReadMetadata(item.Url);
            }
            catch
            {
            }

            if (directories.Count > 0)
            {
                EnrichExif(item, directories);
                EnrichFileDates(item, directories);
                EnrichXmpInitial(item, directories);
            }

            EnrichSidecar(item);

            _cache.Store(item);
        }
        catch
        {
        }
    }

    private static void PopulateFromCache(MediaItem item, MetadataCacheEntry entry)
    {
        item.CaptureDate = entry.CaptureDate;
        item.CameraMake = entry.CameraMake;
        item.CameraModel = entry.CameraModel;
        item.LensModel = entry.LensModel;
        item.FocalLength = entry.FocalLength;
        item.Aperture = entry.Aperture;
        item.ShutterSpeed = entry.ShutterSpeed;
        item.Iso = entry.Iso;
        item.PixelWidth = entry.PixelWidth;
        item.PixelHeight = entry.PixelHeight;
        item.DisplayPixelWidth = entry.DisplayPixelWidth;
        item.DisplayPixelHeight = entry.DisplayPixelHeight;
        item.DisplayRotationDegrees = entry.DisplayRotationDegrees;
        item.ColorSpaceName = entry.ColorSpaceName;
        item.ColorProfileName = entry.ColorProfileName;
    }

    private static void EnrichExif(MediaItem item, IReadOnlyList<MetadataExtractor.Directory> directories)
    {
        var exifIfd0 = directories.OfType<ExifIfd0Directory>().FirstOrDefault();
        var exifSubIfd = directories.OfType<ExifSubIfdDirectory>().FirstOrDefault();

        if (exifIfd0 != null)
        {
            item.CameraMake = exifIfd0.GetDescription(ExifDirectoryBase.TagMake);
            item.CameraModel = exifIfd0.GetDescription(ExifDirectoryBase.TagModel);
            item.PixelWidth = exifIfd0.TryGetInt32(ExifDirectoryBase.TagImageWidth, out var pw) ? pw : null;
            item.PixelHeight = exifIfd0.TryGetInt32(ExifDirectoryBase.TagImageHeight, out var ph) ? ph : null;

            if (exifIfd0.TryGetInt32(ExifDirectoryBase.TagOrientation, out var orientation))
            {
                item.DisplayRotationDegrees = orientation switch
                {
                    3 or 4 => 180,
                    5 or 6 => 90,
                    7 or 8 => 270,
                    _ => 0
                };
            }

            var (dw, dh) = item.DisplayDimensions;
            item.DisplayPixelWidth = dw > 0 ? dw : null;
            item.DisplayPixelHeight = dh > 0 ? dh : null;

            item.ColorSpaceName = exifIfd0.TryGetInt32(ExifDirectoryBase.TagColorSpace, out var cs)
                ? cs switch { 1 => "sRGB", 2 => "Adobe RGB", 65535 => "Uncalibrated", _ => null }
                : null;

            if (directories.OfType<IccDirectory>().FirstOrDefault() is { } iccDir)
            {
                foreach (var tag in iccDir.Tags)
                {
                    var desc = tag.Description?.Trim();
                    if (!string.IsNullOrWhiteSpace(desc) && desc.Length > 3)
                    {
                        item.ColorProfileName = desc;
                        break;
                    }
                }
            }
        }

        if (exifSubIfd != null)
        {
            item.FocalLength = exifSubIfd.TryGetDouble(ExifDirectoryBase.TagFocalLength, out var fl)
                ? fl : null;
            item.Aperture = exifSubIfd.TryGetDouble(ExifDirectoryBase.TagFNumber, out var ap)
                ? ap : null;
            item.ShutterSpeed = exifSubIfd.GetDescription(ExifDirectoryBase.TagExposureTime);
            item.Iso = exifSubIfd.TryGetInt32(ExifDirectoryBase.TagIsoEquivalent, out var iso)
                ? iso : null;
        }

        ExifDirectoryBase? exifDateDir = directories.OfType<ExifSubIfdDirectory>().FirstOrDefault()
            ?? (ExifDirectoryBase?)directories.OfType<ExifIfd0Directory>().FirstOrDefault();

        if (exifDateDir != null)
        {
            if (exifDateDir.TryGetDateTime(ExifDirectoryBase.TagDateTimeOriginal, out var dt))
                item.CaptureDate = dt;
            else if (exifDateDir.TryGetDateTime(ExifDirectoryBase.TagDateTimeDigitized, out dt))
                item.CaptureDate = dt;
            else if (exifDateDir.TryGetDateTime(ExifDirectoryBase.TagDateTime, out dt))
                item.CaptureDate = dt;
        }

        item.LensModel = directories.OfType<ExifDirectoryBase>()
            .Select(d => d.GetDescription(ExifDirectoryBase.TagLensModel))
            .FirstOrDefault(d => !string.IsNullOrWhiteSpace(d));
    }

    private static void EnrichFileDates(MediaItem item, IReadOnlyList<MetadataExtractor.Directory> directories)
    {
        var fileDir = directories.OfType<MetadataExtractor.Formats.FileSystem.FileMetadataDirectory>().FirstOrDefault();
        if (fileDir != null)
        {
            if (fileDir.TryGetDateTime(MetadataExtractor.Formats.FileSystem.FileMetadataDirectory.TagFileModifiedDate, out var mod))
                item.ModifiedDate = mod;
        }
    }

    private static void EnrichXmpInitial(MediaItem item, IReadOnlyList<MetadataExtractor.Directory> directories)
    {
        var xmpDir = directories.OfType<XmpDirectory>().FirstOrDefault();
        if (xmpDir?.XmpMeta != null)
        {
            item.XmpStatus = XmpStatus.SidecarFound;
            var xmp = xmpDir.XmpMeta;

            var ratingStr = xmp.GetPropertyString("http://ns.adobe.com/xap/1.0/", "Rating");
            if (!string.IsNullOrEmpty(ratingStr) && int.TryParse(ratingStr, out var rating))
                item.Rating = rating;

            var label = xmp.GetPropertyString("http://ns.adobe.com/xap/1.0/", "Label");
            if (!string.IsNullOrEmpty(label))
                item.ColorLabel = ParseColorLabel(label);
        }
    }

    private static void EnrichSidecar(MediaItem item)
    {
        var sidecarPath = XmpService.GetSidecarPath(item.Url);
        if (!File.Exists(sidecarPath))
            return;

        var sidecar = new XmpService().Read(sidecarPath);
        item.XmpStatus = XmpStatus.SidecarFound;
        item.Rating = sidecar.Rating;

        if (!string.IsNullOrWhiteSpace(sidecar.Label))
            item.ColorLabel = ParseColorLabel(sidecar.Label);

        item.PickState = sidecar.PickState;
    }

    private static ColorLabel? ParseColorLabel(string label)
    {
        return label.ToLowerInvariant() switch
        {
            "red" or "r" => Models.ColorLabel.Red,
            "yellow" or "y" => Models.ColorLabel.Yellow,
            "green" or "g" => Models.ColorLabel.Green,
            "blue" or "b" => Models.ColorLabel.Blue,
            "purple" or "p" => Models.ColorLabel.Purple,
            _ => null
        };
    }
}
