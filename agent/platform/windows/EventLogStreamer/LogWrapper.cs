using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Web.Script.Serialization;
using System.Diagnostics.Eventing.Reader;

namespace Logmind.EventLogStreamer
{
    internal class LogWrapper
    {
        private IWindowsEventLogProvider m_Log;
        private string m_LogName;
        private LogLocalStorage m_LocalStorage;
        private JavaScriptSerializer m_Ser = null;

        private System.Threading.Timer m_WriteTimer;

        private void Init(string logName)
        {
            m_LogName = logName;
            m_Ser = new JavaScriptSerializer();
            var l = new List<JavaScriptConverter>();
            l.Add(new DateTimeConverter());
            m_Ser.RegisterConverters(l);

            try
            {
                m_LocalStorage = LogLocalStorage.Load(logName);

                m_WriteTimer = new System.Threading.Timer(new System.Threading.TimerCallback(PersistLastLogTime), null, 1000, 3000);

                if(System.Environment.OSVersion.Version.Major > 5) {
                    m_Log = Activator.CreateInstance<NewWindowsEventLogProvider>();
                }
                else {
                    m_Log = Activator.CreateInstance<OldWindowsEventLogProvider>();
                }


                m_Log.StreamEvents(LogWrapper_EntryWritten, logName, m_LocalStorage.LastLogGenerated);
                
            }
            catch (Exception ex)
            {
                LocalLogger.Write(ex);
                throw;
            }
        }

        internal string Name { get { return m_LogName; } }

        internal LogWrapper(string logName)
        {
            Init(logName);
        }

        internal void Stop()
        {
            try
            {
                if (m_WriteTimer != null)
                {
                    m_WriteTimer.Dispose();
                    m_WriteTimer = null;
                }

                if (m_Log != null)
                {
                    m_Log.Stop();
                    m_Log = null;
                }
            }
            catch (Exception ex)
            {
                //NO NEED to do a thing here..
            }
        }

        private void DumpEntry(EventLogItem entry)
        {
            m_LocalStorage.LastLogGenerated = entry.TimeGenerated;
            m_LocalStorage.IsDirty = true;
            Console.WriteLine(m_Ser.Serialize(entry));
        }

        private void LogWrapper_EntryWritten(EventLogItem e)
        {
            DumpEntry(e);
        }

        public void PersistLastLogTime(object state)
        {
            try
            {
                m_LocalStorage.Save();
            }
            catch (Exception ex)
            {
                LocalLogger.Write(ex);
            }
        }
    }
}
