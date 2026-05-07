using System.Management;
using OneMenu.HardwareMonitor.Models;

namespace OneMenu.HardwareMonitor.Readers;

/// <summary>
/// Reads thermal state via WMI MSAcpi_ThermalZoneTemperature.
/// May require admin privileges; returns "不可用" on failure.
/// </summary>
public class ThermalReader
{
    public string ReadThermalState()
    {
        try
        {
            var temps = ReadAllTemperatures();
            if (temps.Count == 0) return "不可用";

            // Map to rough thermal state based on max temperature
            var maxCelsius = temps.Select(t => t.Celsius).DefaultIfEmpty(0).Max();

            return maxCelsius switch
            {
                < 40 => "正常",
                < 60 => "中等",
                < 80 => "严重",
                _ => "危急"
            };
        }
        catch
        {
            return "不可用";
        }
    }

    public List<TemperatureReading> ReadAllTemperatures()
    {
        var results = new List<TemperatureReading>();

        try
        {
            using var searcher = new ManagementObjectSearcher(
                @"root\WMI", "SELECT * FROM MSAcpi_ThermalZoneTemperature");

            foreach (ManagementObject obj in searcher.Get())
            {
                try
                {
                    var tempKelvinTenths = Convert.ToDouble(obj["CurrentTemperature"]);
                    var celsius = (tempKelvinTenths / 10.0) - 273.15;
                    var name = obj["InstanceName"]?.ToString() ?? "CPU";

                    var kind = name.ToLowerInvariant() switch
                    {
                        var n when n.Contains("cpu") || n.Contains("processor") => TemperatureKind.Cpu,
                        var n when n.Contains("gpu") || n.Contains("graphics") => TemperatureKind.Gpu,
                        var n when n.Contains("batt") => TemperatureKind.Battery,
                        _ => TemperatureKind.Other
                    };

                    results.Add(new TemperatureReading(name, Math.Round(celsius, 1), kind));
                }
                catch { }
            }
        }
        catch { }

        return results;
    }
}
