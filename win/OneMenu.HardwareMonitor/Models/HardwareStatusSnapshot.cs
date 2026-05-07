namespace OneMenu.HardwareMonitor.Models;

public enum TemperatureKind { Cpu, Gpu, Battery, Other }

public record TemperatureReading(string Name, double Celsius, TemperatureKind Kind);

public record FanStatus(string Name, double Rpm);

public record GPUStatus(string? Name, double? UsagePercent, string? Note);

public record MemoryStatus(ulong TotalBytes, ulong UsedBytes)
{
    public double UsedPercent =>
        TotalBytes > 0 ? Math.Min(100, Math.Max(0, (double)UsedBytes / TotalBytes * 100)) : 0;
}

public record BatteryStatus(
    int Percent,
    bool IsCharging,
    string PowerSource,
    int? TimeRemainingMinutes);

public record HardwareStatusSnapshot(
    DateTime CapturedAt,
    double? CpuUsagePercent,
    MemoryStatus Memory,
    BatteryStatus? Battery,
    string ThermalState,
    IReadOnlyList<TemperatureReading> Temperatures,
    IReadOnlyList<FanStatus> Fans,
    GPUStatus Gpu)
{
    public TemperatureReading? CpuTemperature =>
        Temperatures.FirstOrDefault(t => t.Kind == TemperatureKind.Cpu);

    public TemperatureReading? GpuTemperature =>
        Temperatures.FirstOrDefault(t => t.Kind == TemperatureKind.Gpu);
}
