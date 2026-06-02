using PreStage.Core.Models;
using PreStage.Core.Services;

namespace PreStage.Tests.Services;

public sealed class WorkspaceServiceTests
{
    [Fact]
    public void SaveLoad_PreservesBranchSelectionAndToolbarMode()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), "PreStageWorkspaceTests", Guid.NewGuid().ToString("N"));
        try
        {
            var service = new WorkspaceService(tempDir);
            var preset = new WorkspacePreset
            {
                Name = "Test",
                LocalSourcePath = @"D:\Photos",
                LocalSourceSelectionPath = @"D:\Photos\Card01",
                LocalTargetPath = @"E:\Archive",
                LocalTargetSelectionPath = @"E:\Archive\2026",
                AppLanguage = AppLanguage.German,
                PanelLayout = new PanelLayout
                {
                    ToolbarDisplayMode = ToolbarDisplayMode.Both
                }
            };

            var library = new WorkspaceLibrary
            {
                ActivePresetId = preset.Id,
                Presets = [preset]
            };

            service.Save(library);

            var loaded = service.Load();
            var active = service.GetActivePreset(loaded);

            Assert.Equal(@"D:\Photos", active.LocalSourcePath);
            Assert.Equal(@"D:\Photos\Card01", active.LocalSourceSelectionPath);
            Assert.Equal(@"E:\Archive", active.LocalTargetPath);
            Assert.Equal(@"E:\Archive\2026", active.LocalTargetSelectionPath);
            Assert.Equal(ToolbarDisplayMode.Both, active.PanelLayout.ToolbarDisplayMode);
            Assert.Equal(AppLanguage.German, active.AppLanguage);
        }
        finally
        {
            if (Directory.Exists(tempDir))
                Directory.Delete(tempDir, recursive: true);
        }
    }
}
