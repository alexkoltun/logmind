using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Management;
using System.Diagnostics.Eventing.Reader;

namespace evLogReader
{
    class Program
    {
        private static List<LogWrapper> m_Logs = new List<LogWrapper>();
        private static AutoResetEvent m_Stop = new AutoResetEvent(false);

        static void Main(string[] args)
        {
            EventLog el = new EventLog("System");
            el.Entries.GetEnumerator()

            return;
            EventLogReader reader = new EventLogReader(new EventLogQuery("System", PathType.LogName, "*[System[(Level <= 3) and TimeCreated[timediff(@SystemTime, '2013-01-01T00:00:00Z') > 0]]]"));
            
            EventRecord r;

            while ((r = reader.ReadEvent(TimeSpan.MaxValue)) != null)
            {
                Console.WriteLine(r.FormatDescription());
            }

            return;

            foreach (var l in EventLog.GetEventLogs())
            {
                EventLogWatcher watcher = new EventLogWatcher(new EventLogQuery(l.Log, PathType.LogName));
                watcher.EventRecordWritten += new EventHandler<EventRecordWrittenEventArgs>(watcher_EventRecordWritten);
                watcher.Enabled = true;
            }

            Thread.Sleep(3600000);

            int pId = GetParentProcessId();
            Process parent = Process.GetProcessById(pId);
            parent.EnableRaisingEvents = true;
            parent.Exited += new EventHandler(parent_Exited);
            LocalLogger.Write(string.Format("waiting for parent process to end , pid is: {0}", parent.ProcessName));

            if (args != null && args.Length > 0)
            {
                string s = args[0];
                var names = s.Split(new char[',']);
                foreach (var name in names)
                {
                    m_Logs.Add(new LogWrapper(name));
                }
            }
            else
            {
                foreach (var l in EventLog.GetEventLogs())
                {
                    m_Logs.Add(new LogWrapper(l));
                }
            }

            m_Stop.WaitOne();

            LocalLogger.Write(string.Format("parent process has ended , process is: {0}, closing all logs", parent.ProcessName));

            foreach (var l in m_Logs)
            {
                l.Stop();
            }
        }

        static void watcher_EventRecordWritten(object sender, EventRecordWrittenEventArgs e)
        {
            Console.WriteLine(e.EventRecord.ToXml());            
        }

        static void parent_Exited(object sender, EventArgs e)
        {
            LocalLogger.Write("setting stop flag");
            m_Stop.Set();
        }

        static int GetParentProcessId()
        {
            Process p = Process.GetCurrentProcess();

            int parentId = 0;
            try
            {
                ManagementObject mo = new ManagementObject("win32_process.handle='" + p.Id + "'");
                mo.Get();
                parentId = Convert.ToInt32(mo["ParentProcessId"]);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.ToString());
                parentId = 0;
            }

            return parentId;
        }
    }
}
