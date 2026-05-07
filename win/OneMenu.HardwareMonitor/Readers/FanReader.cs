using System.Management;
using OneMenu.HardwareMonitor.Models;

namespace OneMenu.HardwareMonitor.Readers;

/// <summary>
/// Reads fan speeds via WMI Win32_Fan.
/// Not available on all Windows systems (desktop/server typically unsupported).
/// </summary>
public class FanReader
{
    public List<FanStatus> ReadFanStatuses()
    {
        var fans = new List<FanStatus>();

        try
        {
            using var searcher = new ManagementObjectSearcher(
                @"root\CIMV2", "SELECT Name, DesiredSpeed FROM Win32_Fan");

            foreach (ManagementObject obj in searcher.Get())
            {
                try
                {
                    var name = obj["Name"]?.ToString() ?? "未知风扇";
                    var rpm = Convert.ToDouble(obj["DesiredSpeed"] ?? 0);
                    if (rpm > 0)
                        fans.Add(new FanStatus(name, rpm));
                }
                catch { }
            }
        }
        catch { }

        return fans;
    }
}
