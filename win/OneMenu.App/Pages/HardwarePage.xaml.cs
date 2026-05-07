using System.Windows;
using System.Windows.Controls;
using OneMenu.Core.Preferences;
using OneMenu.HardwareMonitor;

namespace OneMenu.App.Pages;

public partial class HardwarePage : Page
{
    private readonly HardwareStatusBarPreferences _prefs;
    private readonly HardwareStatusMonitor _monitor;

    public HardwarePage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new HardwareStatusBarPreferences(store);
        _monitor = new HardwareStatusMonitor();

        var metrics = Enum.GetValues<HardwareStatusBarMetric>()
            .Select(m => new { Title = HardwareStatusBarPreferences.MetricTitle(m), Value = m.ToString() })
            .ToList();

        MetricCombo.ItemsSource = metrics;
        MetricCombo.DisplayMemberPath = "Title";
        MetricCombo.SelectedItem = metrics.FirstOrDefault(m => m.Value == _prefs.Metric.ToString());

        RefreshStatus();
    }

    private void OnMetricChanged(object sender, SelectionChangedEventArgs e)
    {
        if (MetricCombo.SelectedItem != null)
        {
            var selected = MetricCombo.SelectedItem;
            var value = selected.GetType().GetProperty("Value")!.GetValue(selected)!.ToString();
            if (Enum.TryParse<HardwareStatusBarMetric>(value, out var metric))
                _prefs.Metric = metric;
        }
    }

    private void OnRefreshClick(object sender, RoutedEventArgs e) => RefreshStatus();

    private void RefreshStatus()
    {
        var snap = _monitor.Snapshot();

        CpuLabel.Text = snap.CpuUsagePercent.HasValue
            ? $"CPU:  {snap.CpuUsagePercent,5:F1}%"
            : "CPU:   检测中...";

        var mem = snap.Memory;
        MemoryLabel.Text = $"内存: {mem.UsedPercent,5:F1}%  ({FormatBytes(mem.UsedBytes)} / {FormatBytes(mem.TotalBytes)})";

        BatteryLabel.Text = snap.Battery != null
            ? $"电池: {snap.Battery.Percent,4}%  {(snap.Battery.IsCharging ? "充电" : "放电")}  ({snap.Battery.PowerSource})"
            : "电池: 无";

        ThermalLabel.Text = $"热状态: {snap.ThermalState}";

        var cpuTemp = snap.CpuTemperature;
        var gpuTemp = snap.GpuTemperature;
        var tempText = new List<string>();
        if (cpuTemp != null) tempText.Add($"CPU {cpuTemp.Celsius}°C");
        if (gpuTemp != null) tempText.Add($"GPU {gpuTemp.Celsius}°C");
        ThermalLabel.Text += tempText.Count > 0 ? $"  ({string.Join(" / ", tempText)})" : "";

        GpuLabel.Text = $"GPU:  {snap.Gpu.Name ?? "未知"}";
        if (snap.Fans.Count > 0)
            GpuLabel.Text += $"  风扇: {string.Join(" ", snap.Fans.Select(f => $"{f.Name}={f.Rpm:F0}RPM"))}";
    }

    private static string FormatBytes(ulong bytes) =>
        bytes switch
        {
            < 1024 => $"{bytes} B",
            < 1024 * 1024 => $"{bytes / 1024.0:F1} KB",
            < 1024L * 1024 * 1024 => $"{bytes / (1024.0 * 1024.0):F1} MB",
            _ => $"{bytes / (1024.0 * 1024.0 * 1024.0):F2} GB"
        };
}
