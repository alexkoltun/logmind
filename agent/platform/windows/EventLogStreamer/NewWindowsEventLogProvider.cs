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
    public class NewWindowsEventLogProvider: IWindowsEventLogProvider   
    {
        private bool _active;
        private EventLogWatcher _watcher;

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


            using (EventLogReader reader = new EventLogReader(new EventLogQuery(logName, PathType.LogName, string.Format("*[System[TimeCreated[timediff(@SystemTime, '{0}') > 0]]]", XmlConvert.ToString(startFrom, XmlDateTimeSerializationMode.Utc)))))
            {
                EventRecord r;
                while (_active && (r = reader.ReadEvent()) != null)
                {
                    EventLogItem item = CreateEventLogItem(r);
                    callback(item);
                }
            }

            if (_active)
            {
                _watcher = new EventLogWatcher(new EventLogQuery(logName, PathType.LogName));
                _watcher.EventRecordWritten += delegate(object sender, EventRecordWrittenEventArgs e)
                {
                    EventLogItem item = CreateEventLogItem(e.EventRecord);
                    callback(item);
                };

                _watcher.Enabled = true;
            }
        }

        private static EventLogItem CreateEventLogItem(EventRecord r)
        {
            try
            {
                EventLogItem item = new EventLogItem
                {
                    Source = r.ProviderName,
                    LogName = r.LogName,
                    Index = (long)(r.RecordId == null ? 0 : r.RecordId),
                    EventID = r.Id,
                    Category = r.TaskDisplayName,
                    Keywords = (r.KeywordsDisplayNames == null ? "" : string.Join(",", r.KeywordsDisplayNames)),
                    Level = r.LevelDisplayName,
                    MachineName = r.MachineName,
                    TimeGenerated = (DateTime)(r.TimeCreated == null ? DateTime.Now : r.TimeCreated),
                    TimeWritten = (DateTime)(r.TimeCreated == null ? DateTime.Now : r.TimeCreated),
                    Message = r.FormatDescription(),
                    UserName = ExtractUsername(r),
                    Properties = ExtractProperties(r),
                    ProcessID = Convert.ToString(r.ProcessId),
                    ThreadID = Convert.ToString(r.ThreadId)
                };
                return item;
            }
            catch (Exception e)
            {
                return new EventLogItem { Message = "Logmind was unable to parse eventlog item, exception: " + e.ToString() };
            }
        }

        private static string ExtractUsername(EventRecord r)
        {
            if (r.UserId == null)
            {
                return string.Empty;
            }

            return ((NTAccount)r.UserId.Translate(typeof(NTAccount))).Value;
        }

        private static string ExtractProperties(EventRecord r)
        {
            if (r.Properties == null)
            {
                return string.Empty;
            }

            return r.Properties.Aggregate(new StringBuilder(), (current, next) => current.Append(",").Append(Convert.ToString(ConvertByteArrayIfNeeded(next.Value)))).ToString();
        }

        private static object ConvertByteArrayIfNeeded(object value)
        {
            if (value is Byte[])
            {
                return BitConverter.ToString((Byte[])value);
            }

            return value;
        }


        public void Stop()
        {
            _active = false;
            if (_watcher != null)
            {
                _watcher.Dispose();
            }
        }
    }
}
