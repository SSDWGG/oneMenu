using OneMenu.Core.Preferences;

namespace OneMenu.App;

public static class ColorHelper
{
    public static System.Drawing.Color ToDrawingColor(this ColorOption option) =>
        System.Drawing.ColorTranslator.FromHtml(option.HexColor);

    public static System.Windows.Media.Color ToMediaColor(this ColorOption option) =>
        (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(option.HexColor);
}
