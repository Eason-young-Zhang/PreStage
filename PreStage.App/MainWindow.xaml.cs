using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using PreStage.Core.Models;

namespace PreStage.App;

public partial class MainWindow : Window
{
    private bool _isInitializing = true;

    public MainWindow()
    {
        InitializeComponent();
        PreviewKeyDown += OnPreviewKeyDown;
        Loaded += (_, _) => _isInitializing = false;
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (DataContext is not ViewModels.MainViewModel vm) return;

        switch (e.Key)
        {
            case Key.D1 when Keyboard.Modifiers == ModifierKeys.Control:
                e.Handled = true;
                vm.SetViewModeCommand.Execute("Grid");
                break;
            case Key.D2 when Keyboard.Modifiers == ModifierKeys.Control:
                e.Handled = true;
                vm.SetViewModeCommand.Execute("List");
                break;
            case Key.D3 when Keyboard.Modifiers == ModifierKeys.Control:
                e.Handled = true;
                vm.SetViewModeCommand.Execute("Gallery");
                break;
            case Key.A when Keyboard.Modifiers == ModifierKeys.Control:
                e.Handled = true;
                break;
            case Key.Space:
                e.Handled = true;
                if (vm.ViewMode != ViewMode.Gallery)
                    vm.SetViewModeCommand.Execute("Gallery");
                break;
            case Key.D0: vm.SetRatingCommand.Execute("0"); break;
            case Key.D1: vm.SetRatingCommand.Execute("1"); break;
            case Key.D2: vm.SetRatingCommand.Execute("2"); break;
            case Key.D3: vm.SetRatingCommand.Execute("3"); break;
            case Key.D4: vm.SetRatingCommand.Execute("4"); break;
            case Key.D5: vm.SetRatingCommand.Execute("5"); break;
            case Key.P:
                vm.SetPickStateCommand.Execute(vm.SelectedItem?.PickState == PickState.Picked
                    ? "Unmarked" : "Pick");
                break;
            case Key.X:
                vm.SetPickStateCommand.Execute(vm.SelectedItem?.PickState == PickState.Rejected
                    ? "Unmarked" : "Reject");
                break;
            case Key.U:
                vm.SetPickStateCommand.Execute("Unmarked");
                break;
            case Key.Delete:
                if (vm.SelectedItem != null)
                {
                    e.Handled = true;
                    vm.SetPickStateCommand.Execute("Reject");
                }
                break;
            case Key.Left:
                if (vm.ViewMode == ViewMode.Gallery)
                {
                    e.Handled = true;
                    vm.NavigateGalleryCommand.Execute("Prev");
                }
                break;
            case Key.Right:
                if (vm.ViewMode == ViewMode.Gallery)
                {
                    e.Handled = true;
                    vm.NavigateGalleryCommand.Execute("Next");
                }
                break;
            case Key.Escape:
                vm.SelectedItem = null;
                break;
        }
    }

    private void SortFieldCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isInitializing) return;
        if (DataContext is not ViewModels.MainViewModel vm) return;
        if (sender is not ComboBox combo) return;

        var field = combo.SelectedIndex switch
        {
            0 => "AddedDate",
            1 => "Name",
            2 => "Kind",
            3 => "ModifiedDate",
            4 => "CreatedDate",
            5 => "LastOpenedDate",
            6 => "Size",
            _ => "AddedDate"
        };

        vm.SetSortFieldCommand.Execute(field);
    }

    private void MoreButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.ContextMenu != null)
        {
            btn.ContextMenu.PlacementTarget = btn;
            btn.ContextMenu.IsOpen = true;
        }
    }
}
