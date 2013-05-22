using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.EventLogStreamer
{
    public class EventLogItem
    {
        public string Category { get; set; }
        public string LogName { get; set; }
        public string OpCode { get; set; }
        public string Keywords { get; set; }
        public string Data { get; set; }
        public string Level { get; set; }
        public int EventID { get; set; }
        public long Index { get; set; }
        public string MachineName { get; set; }
        public string Message { get; set; }
        public string Properties { get; set; }
        public string Source { get; set; }
        public DateTime TimeGenerated { get; set; }
        public DateTime TimeWritten { get; set; }
        public string UserName { get; set; }
        public string ThreadID { get; set; }
        public string ProcessID { get; set; }
    }
}
