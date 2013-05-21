using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Runner
{
    class Program
    {
        private static ProcessController m_Ctrl;

        static void Main(string[] args)
        {
            m_Ctrl = new ProcessController();
            m_Ctrl.Run();

            Console.ReadLine();

            m_Ctrl.Shutdown();

        }
    }
}
