using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using PreStage.ViewModels;

namespace PreStage.App.Views;

public partial class GalleryView : UserControl
{
    private bool _isDragging;
    private Point _dragStartPoint;
    private Thickness _dragStartMargin;
    private Border? _draggedPanel;

    public GalleryView()
    {
        InitializeComponent();
    }

    private void FloatingPanel_DragStart(object sender, MouseButtonEventArgs e)
    {
        if (sender is not Border panel) return;
        _draggedPanel = panel;
        _isDragging = true;
        _dragStartPoint = e.GetPosition(this);
        _dragStartMargin = panel.Margin;
        panel.CaptureMouse();
    }

    private void FloatingPanel_DragMove(object sender, MouseEventArgs e)
    {
        if (!_isDragging || _draggedPanel == null) return;

        var currentPos = e.GetPosition(this);
        var deltaX = currentPos.X - _dragStartPoint.X;
        var deltaY = currentPos.Y - _dragStartPoint.Y;

        var newLeft = Math.Max(0, _dragStartMargin.Left + deltaX);
        var newTop = Math.Max(0, _dragStartMargin.Top + deltaY);
        _draggedPanel.Margin = new Thickness(newLeft, newTop, 0, 0);
    }

    private void FloatingPanel_DragEnd(object sender, MouseButtonEventArgs e)
    {
        if (_draggedPanel != null)
        {
            _draggedPanel.ReleaseMouseCapture();
            _draggedPanel = null;
        }

        _isDragging = false;
    }

    private void Filmstrip_MouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (sender is not ScrollViewer sv) return;
        sv.ScrollToHorizontalOffset(sv.HorizontalOffset - e.Delta);
        e.Handled = true;
    }
}
