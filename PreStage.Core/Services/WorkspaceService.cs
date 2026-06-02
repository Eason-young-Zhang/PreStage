using System.Text.Json;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class WorkspaceService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly string _settingsDir;
    private readonly string _settingsFile;

    public WorkspaceService(string? settingsDir = null)
    {
        _settingsDir = settingsDir ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PreStage");
        _settingsFile = Path.Combine(_settingsDir, "workspace.json");
    }

    public WorkspaceLibrary Load()
    {
        try
        {
            if (File.Exists(_settingsFile))
            {
                var json = File.ReadAllText(_settingsFile);
                var library = JsonSerializer.Deserialize<WorkspaceLibrary>(json, JsonOptions);
                if (library?.Presets is { Count: > 0 })
                {
                    return library;
                }
            }
        }
        catch
        {
        }

        return WorkspaceLibrary.Default;
    }

    public void Save(WorkspaceLibrary library)
    {
        try
        {
            Directory.CreateDirectory(_settingsDir);
            var json = JsonSerializer.Serialize(library, JsonOptions);
            File.WriteAllText(_settingsFile, json);
        }
        catch
        {
        }
    }

    public WorkspacePreset GetActivePreset(WorkspaceLibrary library)
    {
        return library.Presets.FirstOrDefault(p => p.Id == library.ActivePresetId)
               ?? library.Presets.FirstOrDefault()
               ?? WorkspacePreset.Default;
    }

    public void ApplyPreset(WorkspaceLibrary library, WorkspacePreset preset)
    {
        library.ActivePresetId = preset.Id;
        if (!library.Presets.Any(p => p.Id == preset.Id))
        {
            library.Presets.Add(preset);
        }
    }
}
