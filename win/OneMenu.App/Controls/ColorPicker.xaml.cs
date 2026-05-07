using System.Windows;
using System.Windows.Controls;
using OneMenu.Core.Preferences;

namespace OneMenu.App.Controls;

public partial class ColorPicker : UserControl
{
    public static readonly DependencyProperty HeaderProperty =
        DependencyProperty.Register(nameof(Header), typeof(string), typeof(ColorPicker));

    public static readonly DependencyProperty SelectedColorIdProperty =
        DependencyProperty.Register(nameof(SelectedColorId), typeof(string), typeof(ColorPicker),
            new FrameworkPropertyMetadata("blue", FrameworkPropertyMetadataOptions.BindsTwoWayByDefault,
                OnSelectedColorIdChanged));

    public static readonly DependencyProperty ColorOptionsProperty =
        DependencyProperty.Register(nameof(ColorOptions), typeof(List<ColorDefinitions.ColorOption>), typeof(ColorPicker));

    public string Header
    {
        get => (string)GetValue(HeaderProperty);
        set => SetValue(HeaderProperty, value);
    }

    public string SelectedColorId
    {
        get => (string)GetValue(SelectedColorIdProperty);
        set => SetValue(SelectedColorIdProperty, value);
    }

    public List<ColorDefinitions.ColorOption> ColorOptions
    {
        get => (List<ColorDefinitions.ColorOption>)GetValue(ColorOptionsProperty);
        set => SetValue(ColorOptionsProperty, value);
    }

    public event EventHandler<string>? ColorChanged;

    public ColorPicker()
    {
        InitializeComponent();
        DataContext = this;
    }

    protected override void OnPropertyChanged(DependencyPropertyChangedEventArgs e)
    {
        base.OnPropertyChanged(e);
        if (e.Property == HeaderProperty)
            HeaderLabel.Text = (string)e.NewValue;
        if (e.Property == ColorOptionsProperty)
            ColorCombo.ItemsSource = (List<ColorDefinitions.ColorOption>)e.NewValue;
        if (e.Property == SelectedColorIdProperty && ColorOptions != null)
        {
            var selected = ColorOptions.FirstOrDefault(c => c.Id == (string)e.NewValue);
            if (selected != null && ColorCombo.SelectedItem != selected)
                ColorCombo.SelectedItem = selected;
        }
    }

    private static void OnSelectedColorIdChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is ColorPicker picker)
            picker.OnPropertyChanged(new DependencyPropertyChangedEventArgs(SelectedColorIdProperty, e.OldValue, e.NewValue));
    }

    private void OnColorChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ColorCombo.SelectedItem is ColorDefinitions.ColorOption option)
        {
            SelectedColorId = option.Id;
            ColorChanged?.Invoke(this, option.Id);
        }
    }
}
