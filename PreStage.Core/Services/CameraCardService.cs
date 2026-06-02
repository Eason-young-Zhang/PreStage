using System.IO;
using System.Timers;

namespace PreStage.Core.Services;

public sealed class CameraCardInfo
{
    public string DriveName { get; init; } = "";
    public string DriveLabel { get; init; } = "";
    public string RootPath { get; init; } = "";
    public string? DcimPath { get; init; }
    public long TotalSize { get; init; }
    public long AvailableFreeSpace { get; init; }
    public bool HasDcim => !string.IsNullOrWhiteSpace(DcimPath);
}

public sealed class CameraCardService : IDisposable
{
    private readonly System.Timers.Timer _pollTimer = new(3000);
    private readonly object _gate = new();
    private List<CameraCardInfo> _lastCards = [];

    public event Action<IReadOnlyList<CameraCardInfo>>? CardsChanged;
    public event Action<CameraCardInfo>? CardDetected;
    public event Action<CameraCardInfo>? CardRemoved;

    public CameraCardService()
    {
        _pollTimer.AutoReset = true;
        _pollTimer.Elapsed += (_, _) => Poll();
    }

    public IReadOnlyList<CameraCardInfo> Start()
    {
        var cards = Poll();
        _pollTimer.Start();
        return cards;
    }

    public void Stop()
    {
        _pollTimer.Stop();
    }

    public IReadOnlyList<CameraCardInfo> Poll()
    {
        lock (_gate)
        {
            var current = EnumerateCards();
            var added = current
                .Where(card => _lastCards.All(previous =>
                    !string.Equals(previous.RootPath, card.RootPath, StringComparison.OrdinalIgnoreCase)))
                .ToList();
            var removed = _lastCards
                .Where(previous => current.All(card =>
                    !string.Equals(previous.RootPath, card.RootPath, StringComparison.OrdinalIgnoreCase)))
                .ToList();

            _lastCards = current;

            foreach (var card in added)
                CardDetected?.Invoke(card);
            foreach (var card in removed)
                CardRemoved?.Invoke(card);

            if (added.Count > 0 || removed.Count > 0)
                CardsChanged?.Invoke(_lastCards);

            return _lastCards;
        }
    }

    public static bool TryEject(string rootPath)
    {
        // TODO: Use a safe Windows device-eject API. Avoid shelling out with
        // interpolated paths because drive labels and paths are user-controlled.
        return false;
    }

    public void Dispose()
    {
        _pollTimer.Dispose();
    }

    private static List<CameraCardInfo> EnumerateCards()
    {
        try
        {
            return DriveInfo.GetDrives()
                .Where(drive => drive.IsReady && drive.DriveType == DriveType.Removable)
                .Select(ToCardInfo)
                .ToList();
        }
        catch
        {
            return [];
        }
    }

    private static CameraCardInfo ToCardInfo(DriveInfo drive)
    {
        var root = drive.RootDirectory.FullName;
        return new CameraCardInfo
        {
            DriveName = drive.Name,
            DriveLabel = string.IsNullOrWhiteSpace(drive.VolumeLabel) ? drive.Name : drive.VolumeLabel,
            RootPath = root,
            DcimPath = FindDcimFolder(root),
            TotalSize = SafeDriveValue(() => drive.TotalSize),
            AvailableFreeSpace = SafeDriveValue(() => drive.AvailableFreeSpace)
        };
    }

    private static long SafeDriveValue(Func<long> read)
    {
        try
        {
            return read();
        }
        catch
        {
            return 0;
        }
    }

    private static string? FindDcimFolder(string rootPath)
    {
        try
        {
            var dcim = Path.Combine(rootPath, "DCIM");
            if (Directory.Exists(dcim))
                return dcim;

            return Directory.EnumerateDirectories(rootPath)
                .FirstOrDefault(dir => string.Equals(
                    Path.GetFileName(dir),
                    "DCIM",
                    StringComparison.OrdinalIgnoreCase));
        }
        catch
        {
            return null;
        }
    }
}
