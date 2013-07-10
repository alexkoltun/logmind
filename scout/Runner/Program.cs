using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Dynamic;
using Logmind.Domain;
using Logmind.Domain.Requests;

namespace Logmind.Runner
{
    class Program
    {
        private static ProcessController m_Ctrl;

        static void Main(string[] args)
        {

            //MsgData msg = new MsgData();
            ////x.
            //dynamic d = msg.Data;
            //d.Prop1 = "test1";
            //d.prop2 = "test2";

            //var json = msg.ToJson();

            m_Ctrl = new ProcessController();
            m_Ctrl.Run();

            Console.ReadLine();

            m_Ctrl.Shutdown();

        }
    }
}
