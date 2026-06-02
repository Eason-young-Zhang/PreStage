using CommunityToolkit.Mvvm.ComponentModel;
using PreStage.Core.Localization;

namespace PreStage.ViewModels;

public sealed class LocalizedText : ObservableObject
{
    public string this[string key] => L10n.Tr(key);

    public void Refresh()
    {
        OnPropertyChanged("Item[]");
    }
}
