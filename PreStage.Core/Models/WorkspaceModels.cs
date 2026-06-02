namespace PreStage.Core.Models;

public sealed class WorkspacePreset
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public string Name { get; init; } = "Default";
    public PanelLayout PanelLayout { get; init; } = new();
    public ViewMode ViewMode { get; init; } = ViewMode.Grid;
    public FilterState FilterState { get; init; } = new();
    public SortRule SortRule { get; init; } = SortRule.Default;
    public CopyOrganizationRule CopyRule { get; init; } = CopyOrganizationRule.CaptureDate;
    public CopyConflictPolicy CopyConflictPolicy { get; init; } = CopyConflictPolicy.AutoRename;
    public CopyContentMode CopyContentMode { get; init; } = CopyContentMode.AllSupported;
    public CopyVerificationMode CopyVerificationMode { get; init; } = CopyVerificationMode.SizeOnly;
    public string? LocalSourcePath { get; set; }
    public string? LocalSourceSelectionPath { get; set; }
    public string? LocalTargetPath { get; set; }
    public string? LocalTargetSelectionPath { get; set; }
    public Dictionary<string, MediaTransform> MediaTransforms { get; init; } = [];
    public List<CopyLogRecord> CopyLogs { get; init; } = [];
    public List<BatchRenameLogRecord> BatchRenameLogs { get; init; } = [];
    public bool PreservePaths { get; init; } = true;
    public AppLanguage AppLanguage { get; init; } = AppLanguage.System;
    public bool IncludeSourceSubfolders { get; init; }
    public CameraCardAction CameraCardAction { get; init; } = CameraCardAction.Notify;

    public static WorkspacePreset Default => new()
    {
        Id = Guid.NewGuid(),
        Name = "Default",
        PanelLayout = new PanelLayout(),
        ViewMode = ViewMode.Grid,
        FilterState = new FilterState(),
        SortRule = SortRule.Default,
        CopyRule = CopyOrganizationRule.CaptureDate,
        CopyConflictPolicy = CopyConflictPolicy.AutoRename,
        CopyContentMode = CopyContentMode.AllSupported,
        CopyVerificationMode = CopyVerificationMode.SizeOnly,
        PreservePaths = true,
        AppLanguage = AppLanguage.System,
        CameraCardAction = CameraCardAction.Notify
    };
}

public sealed class WorkspaceLibrary
{
    public Guid ActivePresetId { get; set; }
    public List<WorkspacePreset> Presets { get; init; } = [];

    public static WorkspaceLibrary Default => new()
    {
        ActivePresetId = WorkspacePreset.Default.Id,
        Presets = [WorkspacePreset.Default]
    };
}
