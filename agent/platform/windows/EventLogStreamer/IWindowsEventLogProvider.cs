using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.EventLogStreamer
{
    public delegate void OnEventDelegate(EventLogItem e);
    public interface IWindowsEventLogProvider
    {
        void StreamEvents(OnEventDelegate callback, string logName, DateTime startFrom);
        void Stop();
    }
}
