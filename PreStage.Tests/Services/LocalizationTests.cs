using PreStage.Core.Localization;

namespace PreStage.Tests.Services;

public sealed class LocalizationTests
{
    [Fact]
    public void Tr_ReturnsChineseAndGermanValues()
    {
        L10n.SetLanguage("zh-CN");
        Assert.Equal("源目录", L10n.Tr("Source"));
        Assert.Equal("刷新设备", L10n.Tr("Refresh Devices"));

        L10n.SetLanguage("de-DE");
        Assert.Equal("Quelle", L10n.Tr("Source"));
        Assert.Equal("Geräte aktualisieren", L10n.Tr("Refresh Devices"));

        L10n.SetLanguage("en-US");
        Assert.Equal("Source", L10n.Tr("Source"));
    }
}
