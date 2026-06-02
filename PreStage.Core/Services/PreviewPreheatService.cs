using System.Collections.Concurrent;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class PreviewPreheatService
{
    private readonly ConcurrentDictionary<string, PreviewImageService.PreviewResult> _cache = new();
    private readonly PreviewImageService _previewImage = new();
    private CancellationTokenSource? _cts;

    public async Task PreheatAsync(MediaItem center, List<MediaItem> allItems, int range = 3)
    {
        _cts?.Cancel();
        _cts = new CancellationTokenSource();
        var token = _cts.Token;

        var idx = allItems.IndexOf(center);
        if (idx < 0) return;

        var start = Math.Max(0, idx - range);
        var end = Math.Min(allItems.Count - 1, idx + range);

        for (var i = start; i <= end; i++)
        {
            token.ThrowIfCancellationRequested();
            var item = allItems[i];
            if (_cache.ContainsKey(item.Url)) continue;

            try
            {
                var result = await Task.Run(() =>
                    _previewImage.LoadPreview(item.Url, 2560, 1440), token);

                if (result != null)
                    _cache.TryAdd(item.Url, result);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch
            {
            }
        }
    }

    public PreviewImageService.PreviewResult? TryGetCached(string url)
    {
        return _cache.TryGetValue(url, out var result) ? result : null;
    }

    public void ClearCache()
    {
        _cache.Clear();
    }
}
