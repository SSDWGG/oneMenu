using System.Windows.Forms;
using OneMenu.HardwareMonitor.Models;

namespace OneMenu.HardwareMonitor.Readers;

public class BatteryReader
{
    public BatteryStatus? ReadBatteryStatus()
    {
        try
        {
            var ps = SystemInformation.PowerStatus;

            if (ps.BatteryLifePercent < 0 || ps.BatteryLifePercent > 1.0f)
                return null; // no battery present or unknown

            var percent = (int)Math.Round(ps.BatteryLifePercent * 100);
            var isCharging = ps.PowerLineStatus == PowerLineStatus.Online;
            var source = ps.PowerLineStatus switch
            {
                PowerLineStatus.Online => "电源适配器",
                PowerLineStatus.Offline => "电池",
                _ => "未知"
            };

            int? timeRemaining = ps.BatteryLifeRemaining > 0 ? ps.BatteryLifeRemaining / 60 : null;

            return new BatteryStatus(percent, isCharging, source, timeRemaining);
        }
        catch
        {
            return null;
        }
    }
}
