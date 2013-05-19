using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Web.Script.Serialization;
using System.Diagnostics.Eventing.Reader;

namespace evLogReader
{
    internal class LogWrapper
    {
        private EventLog m_Log;
        private LogLocalStorage m_LocalStorage;
        private JavaScriptSerializer m_Ser = null;

        private System.Threading.Timer m_WriteTimer;

        private void Init(string logName)
        {
            m_Ser = new JavaScriptSerializer();
            var l = new List<JavaScriptConverter>();
            l.Add(new DateTimeConverter());
            m_Ser.RegisterConverters(l);

            try
            {
                m_LocalStorage = LogLocalStorage.Load(logName);

                m_WriteTimer = new System.Threading.Timer(new System.Threading.TimerCallback(PersistLastLogTime), null, 1000, 3000);

                ReadBacklog();

                m_Log.EnableRaisingEvents = true;
                m_Log.EntryWritten += new EntryWrittenEventHandler(LogWrapper_EntryWritten);
            }
            catch (Exception ex)
            {
                LocalLogger.Write(ex);
                throw;
            }
        }

        private void ReadBacklog()
        {
            var backLog = from EventLogEntry entry in m_Log.Entries
                          where entry.TimeGenerated > m_LocalStorage.LastLogGenerated
                          select entry;

            var lst = backLog.ToList();
            if (lst != null)
            {
                foreach (var e in lst)
                {
                    DumpEntry(e);
                }
            }
        }

        internal string Name { get { return m_Log.Log; } }

        internal LogWrapper(string logName)
        {
            m_Log = new EventLog(logName);
            Init(logName);
        }

        internal LogWrapper(EventLog log)
        {
            m_Log = log;
            Init(log.Log);
        }

        internal void Stop()
        {
            try
            {
                m_WriteTimer.Dispose();
                m_WriteTimer = null;

                m_Log.Dispose();
                m_Log = null;
            }
            catch (Exception ex)
            {
                //NO NEED to do a thing here..
            }
        }

        private void DumpEntry(EventLogEntry entry)
        {
            if (entry.TimeGenerated > m_LocalStorage.LastLogGenerated)
            {
                m_LocalStorage.LastLogGenerated = entry.TimeGenerated;
                m_LocalStorage.IsDirty = true;
                Console.WriteLine(m_Ser.Serialize(entry));
            }
        }
        private void LogWrapper_EntryWritten(object sender, EntryWrittenEventArgs e)
        {
            DumpEntry(e.Entry);
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
