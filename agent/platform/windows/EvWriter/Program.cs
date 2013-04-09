using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Threading;

namespace EvWriter
{
    class Program
    {
        static void Main(string[] args)
        {
            //Process.Start("evLogReader.exe");

            for (int i = 0; i < 20; i++)
            {
                
                EventLog.WriteEntry("test", "verynew_with1" + i.ToString(), System.Diagnostics.EventLogEntryType.Warning);
                Console.WriteLine(i);
                Thread.Sleep(3000);

            }
        }
    }
}
