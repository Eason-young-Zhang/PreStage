using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class MediaPairingService
{
    public void PairRawAndJpeg(List<MediaItem> items)
    {
        var raws = items.Where(i => i.MediaType == MediaType.Raw).ToList();
        var jpegs = items.Where(i => i.MediaType == MediaType.Jpeg).ToList();

        foreach (var raw in raws)
        {
            var baseName = Path.GetFileNameWithoutExtension(raw.Filename);
            var partner = jpegs.FirstOrDefault(j =>
                string.Equals(Path.GetFileNameWithoutExtension(j.Filename), baseName,
                    StringComparison.OrdinalIgnoreCase));

            if (partner != null)
            {
                raw.PairedAssetKey = partner.Url;
                partner.PairedAssetKey = raw.Url;
                partner.PickState = raw.PickState;
                partner.Rating = raw.Rating;
                partner.ColorLabel = raw.ColorLabel;
            }
        }
    }

    public MediaItem? GetPairedItem(MediaItem item, List<MediaItem> allItems)
    {
        if (string.IsNullOrEmpty(item.PairedAssetKey)) return null;
        return allItems.FirstOrDefault(i => i.Url == item.PairedAssetKey);
    }

    public List<MediaItem> CollapsePairs(List<MediaItem> items)
    {
        var result = new List<MediaItem>();
        var seenUrls = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var item in items)
        {
            if (seenUrls.Contains(item.Url)) continue;
            seenUrls.Add(item.Url);

            if (!string.IsNullOrEmpty(item.PairedAssetKey))
                seenUrls.Add(item.PairedAssetKey);

            result.Add(item);
        }

        return result;
    }
}
