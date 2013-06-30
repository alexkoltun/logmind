using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Management;
using System.Diagnostics.Eventing.Reader;
using System.ComponentModel;
using System.Globalization;


namespace Logmind.EventLogStreamer
{
    class Program
    {
        private static List<LogWrapper> m_Logs = new List<LogWrapper>();

        static void Main(string[] args)
        {
            Thread.CurrentThread.CurrentCulture = new CultureInfo("en-US");

            Console.OutputEncoding = Encoding.UTF8;

            int pId = GetParentProcessId();
            Process parent = Process.GetProcessById(pId);

            Thread t = new Thread(delegate()
            {
                parent.WaitForExit();
                Thread.Sleep(3000);
                Environment.Exit(0);
            });
            t.Start();

            LocalLogger.Write(string.Format("waiting for parent process to end , pid is: {0}, process name is: {1}", parent.Id, parent.ProcessName));

            if (args != null && args.Length > 0)
            {
                string s = args[0];
                var names = s.Split(',');
                foreach (var name in names)
                {
                    m_Logs.Add(new LogWrapper(name));
                }
            }
            else
            {
                foreach (var l in EventLog.GetEventLogs())
                {
                    m_Logs.Add(new LogWrapper(l.Log));
                }
            }

            parent.WaitForExit();

            LocalLogger.Write(string.Format("parent process has ended , process is: {0}, closing all logs", parent.ProcessName));

            foreach (var l in m_Logs)
            {
                l.Stop();
            }

            Environment.Exit(0);
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
