using System.Management;
using OneMenu.HardwareMonitor.Models;

namespace OneMenu.HardwareMonitor.Readers;

public class GpuReader
{
    private string? _cachedName;
    private bool _loaded;

    public GPUStatus ReadGpuStatus()
    {
        if (!_loaded)
        {
            _cachedName = LoadGpuName();
            _loaded = true;
        }

        return new GPUStatus(
            Name: _cachedName,
            UsagePercent: null,
            Note: "Windows 未提供稳定公开的 GPU 使用率 API；当前显示 GPU 名称（如可用）。");
    }

    private static string? LoadGpuName()
    {
        try
        {
            using var searcher = new ManagementObjectSearcher(
                @"root\CIMV2", "SELECT Name FROM Win32_VideoController");

            var names = new List<string>();
            foreach (ManagementObject obj in searcher.Get())
            {
                var name = obj["Name"]?.ToString();
                if (!string.IsNullOrEmpty(name))
                    names.Add(name);
            }

            return names.Count > 0 ? string.Join(" / ", names) : null;
        }
        catch
        {
            return null;
        }
    }
}
