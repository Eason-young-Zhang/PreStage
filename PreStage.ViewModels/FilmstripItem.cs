using PreStage.Core.Models;

namespace PreStage.ViewModels;

public sealed class FilmstripItem
{
    public MediaItem Item { get; }
    public double Width { get; }

    public FilmstripItem(MediaItem item)
    {
        Item = item;

        var ratio = item.DisplayAspectRatio;
        if (ratio is > 0)
            Width = Math.Clamp(72.0 * ratio.Value, 48.0, 200.0);
        else
            Width = 60.0;
    }
}
