namespace OneMenu.Core.Preferences;

public enum HardwareStatusBarMetric
{
    CpuUsage, MemoryUsage, BatteryLevel, ThermalState,
    CpuTemperature, GpuTemperature, FanSpeed
}

public class HardwareStatusBarPreferences
{
    private const string Key = "hardwareStatusBarMetric";
    private readonly PreferencesStore _store;

    public HardwareStatusBarPreferences(PreferencesStore store) => _store = store;

    public HardwareStatusBarMetric Metric
    {
        get
        {
            var rawValue = _store.GetString(Key);
            if (Enum.TryParse<HardwareStatusBarMetric>(rawValue, out var metric))
                return metric;
            return HardwareStatusBarMetric.CpuUsage;
        }
        set => _store.Set(Key, value.ToString());
    }

    public static string MetricTitle(HardwareStatusBarMetric metric) => metric switch
    {
        HardwareStatusBarMetric.CpuUsage => "CPU 使用率",
        HardwareStatusBarMetric.MemoryUsage => "内存使用率",
        HardwareStatusBarMetric.BatteryLevel => "电池电量",
        HardwareStatusBarMetric.ThermalState => "热状态",
        HardwareStatusBarMetric.CpuTemperature => "CPU 温度",
        HardwareStatusBarMetric.GpuTemperature => "GPU 温度",
        HardwareStatusBarMetric.FanSpeed => "风扇转速",
        _ => metric.ToString()
    };
}
