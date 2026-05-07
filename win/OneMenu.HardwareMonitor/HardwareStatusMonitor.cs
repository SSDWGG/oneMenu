using OneMenu.HardwareMonitor.Models;
using OneMenu.HardwareMonitor.Readers;

namespace OneMenu.HardwareMonitor;

public class HardwareStatusMonitor
{
    private readonly CpuReader _cpu;
    private readonly MemoryReader _memory;
    private readonly BatteryReader _battery;
    private readonly ThermalReader _thermal;
    private readonly GpuReader _gpu;
    private readonly FanReader _fan;

    public HardwareStatusMonitor()
    {
        _cpu = new CpuReader();
        _memory = new MemoryReader();
        _battery = new BatteryReader();
        _thermal = new ThermalReader();
        _gpu = new GpuReader();
        _fan = new FanReader();
    }

    public HardwareStatusSnapshot Snapshot()
    {
        return new HardwareStatusSnapshot(
            CapturedAt: DateTime.Now,
            CpuUsagePercent: _cpu.ReadCpuUsagePercent(),
            Memory: _memory.ReadMemoryStatus(),
            Battery: _battery.ReadBatteryStatus(),
            ThermalState: _thermal.ReadThermalState(),
            Temperatures: _thermal.ReadAllTemperatures(),
            Fans: _fan.ReadFanStatuses(),
            Gpu: _gpu.ReadGpuStatus());
    }
}
