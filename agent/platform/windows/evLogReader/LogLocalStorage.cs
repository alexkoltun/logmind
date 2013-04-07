using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Xml.Serialization;
using System.IO;

namespace evLogReader
{
    [XmlRoot("localStorage")]
    public class LogLocalStorage
    {
        private string m_logName;

        [XmlElement("lastLogGenerated")]
        public DateTime LastLogGenerated { get; set; }

        [XmlIgnore()]
        public bool IsDirty { get; set; }

        private static string GetFilePath(string logName)
        {
            var currentFolder = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            return Path.Combine(currentFolder, string.Format("storage_{0}.xml", logName));
        }

        public static LogLocalStorage Load(string logName)
        {
            string file = GetFilePath(logName);

            LogLocalStorage retVal = null;

            if (File.Exists(file))
            {
                try
                {
                    using (StreamReader reader = new StreamReader(file))
                    {
                        XmlSerializer ser = new XmlSerializer(typeof(LogLocalStorage));
                        retVal = (LogLocalStorage)ser.Deserialize(reader);
                    }
                }
                catch (Exception ex)
                {
                    retVal = new LogLocalStorage();
                }
            }
            else
            {
                retVal = new LogLocalStorage();
            }
            
            retVal.m_logName = logName;
            return retVal;
        }

        public void Save()
        {
            if (IsDirty == false)
                return;

            string file = GetFilePath(m_logName);

            try
            {
                using (StreamWriter writer = new StreamWriter(file))
                {
                    XmlSerializer ser = new XmlSerializer(typeof(LogLocalStorage));
                    ser.Serialize(writer, this);
                    IsDirty = false;
                }
            }
            catch (Exception ex)
            {
                LocalLogger.Write(ex);
            }

        }
    }  
}
