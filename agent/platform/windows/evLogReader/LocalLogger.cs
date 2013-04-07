using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

namespace evLogReader
{
    internal static class LocalLogger
    {
        private static object m_Lock = new object();

        internal static void Write(Exception ex)
        {
            Write(ex.ToString());
        }

        internal static void Write(string s)
        {
            var currentFolder = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            string file = Path.Combine(currentFolder, "evLogreader.log");

            lock (m_Lock)
            {
                using (StreamWriter writer = new StreamWriter(file, false))
                {
                    writer.WriteLine(string.Format("{0}\t{1}",DateTime.Now.ToString(),s));
                }
            }
         }

    }
}
