using System.Runtime.InteropServices;
using OneMenu.HardwareMonitor.Models;

namespace OneMenu.HardwareMonitor.Readers;

public class MemoryReader
{
    [StructLayout(LayoutKind.Sequential)]
    private struct MEMORYSTATUSEX
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    public MemoryStatus ReadMemoryStatus()
    {
        var mex = new MEMORYSTATUSEX { dwLength = (uint)Marshal.SizeOf<MEMORYSTATUSEX>() };

        if (GlobalMemoryStatusEx(ref mex))
        {
            var total = mex.ullTotalPhys;
            var available = mex.ullAvailPhys;
            var used = total - available;
            return new MemoryStatus(total, used);
        }

        return new MemoryStatus(0, 0);
    }
}
