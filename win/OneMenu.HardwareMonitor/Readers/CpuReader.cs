using System.Diagnostics;
using OneMenu.HardwareMonitor.Models;

namespace OneMenu.HardwareMonitor.Readers;

/// <summary>
/// CPU usage via PerformanceCounter. On first call returns null (needs two samples).
/// </summary>
public class CpuReader
{
    private PerformanceCounter? _totalCounter;
    private float? _previousValue;

    public CpuReader()
    {
        try
        {
            _totalCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
            _ = _totalCounter.NextValue(); // prime the counter
        }
        catch
        {
            _totalCounter = null;
        }
    }

    public double? ReadCpuUsagePercent()
    {
        if (_totalCounter == null) return null;
        try
        {
            var current = _totalCounter.NextValue();
            if (_previousValue == null)
            {
                _previousValue = current;
                return null;
            }
            _previousValue = current;
            return Math.Round(current, 1);
        }
        catch
        {
            return null;
        }
    }
}
