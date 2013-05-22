using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Diagnostics.Eventing.Reader;
using System.Diagnostics;
using System.Xml;
using System.Security.Principal;

namespace Logmind.EventLogStreamer
{
    public class OldWindowsEventLogProvider : IWindowsEventLogProvider
    {
        private EventLog _el;
        private bool _active;

        public void StreamEvents(OnEventDelegate callback, string logName, DateTime startFrom)
        {
            if (callback == null)
            {
                throw new ArgumentException("callback cannot be null", "callback");
            }

            if (logName == null)
            {
                throw new ArgumentException("logName cannot be null", "logName");
            }

            Stop();
            _active = true;

            _el = new EventLog(logName);
            int cnt = _el.Entries.Count;

            for (int i = 0; _active && i < cnt; i++)
            {
                if (_el.Entries[i].TimeGenerated > startFrom)
                {
                    callback(CreateEventLogItem(_el.Entries[i], logName));
                }
            }

            if (_active)
            {
                _el.EntryWritten += new EntryWrittenEventHandler(delegate(object sender, EntryWrittenEventArgs e)
                {
                    for (int i = cnt; i < _el.Entries.Count; i++)
                    {
                        callback(CreateEventLogItem(_el.Entries[i], logName));
                    }
                });

                _el.EnableRaisingEvents = true;
            }
        }

        private static EventLogItem CreateEventLogItem(EventLogEntry e, string logName)
        {
            try
            {
                EventLogItem item = new EventLogItem
                {
                    Source = e.Source,
                    LogName = logName,
                    Index = e.Index,
                    EventID = e.EventID,
                    Category = e.Category,
                    Level = ExtractLevel(e),
                    MachineName = e.MachineName,
                    TimeGenerated = e.TimeGenerated,
                    TimeWritten = e.TimeWritten,
                    Message = e.Message,
                    UserName = e.UserName,
                    Properties = (e.ReplacementStrings == null ? "" : string.Join(",", e.ReplacementStrings.Union(e.Data == null ? new string[] {} : new string[] { BitConverter.ToString((Byte[])e.Data) })))
                };
                return item;
            }
            catch (Exception ex)
            {
                return new EventLogItem { Message = "Logmind was unable to parse eventlog item, exception: " + ex.ToString() };
            }
        }

        private static string ExtractLevel(EventLogEntry e)
        {
            switch (e.EntryType)
            {
                case EventLogEntryType.Error:
                    return "Error";
                case EventLogEntryType.Information:
                    return "Information";
                case EventLogEntryType.Warning:
                    return "Warning";
                case EventLogEntryType.FailureAudit:
                    return "Audit Failure";
                case EventLogEntryType.SuccessAudit:
                    return "Audit Success";
            }

            return "Unknown";
        }

        private static string ExtractUsername(EventRecord r)
        {
            if (r.UserId == null)
            {
                return string.Empty;
            }

            return ((NTAccount)r.UserId.Translate(typeof(NTAccount))).Value;
        }


        public void Stop()
        {
            _active = false;

            if (_el != null)
            {
                _el.Dispose();
                _el = null;
            }
        }
    }
}
