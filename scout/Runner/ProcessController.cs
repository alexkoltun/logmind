using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Runner
{
    internal class ProcessController
    {
        Logmind.ConfigurationManager.ConfigurationManager m_ConfigManager;
        Logmind.DataDelivery.Postman m_PostMan;

        internal ProcessController()
        { }

        internal void Run()
        {
            Persistance.PersistanceManager.Init();

            m_ConfigManager = new ConfigurationManager.ConfigurationManager();
            m_ConfigManager.Init();

            m_PostMan = new DataDelivery.Postman();
            m_PostMan.Init(m_ConfigManager);

            //PostmanConfig testC = new PostmanConfig() { SizeThreshold = 500, TimeThreshold = 500 };

           // Persistance.PersistanceManager.SaveConfigObject(Domain.ModulesTypes.DataDelivery, testC);
        }

        internal void Shutdown()
        {
            Persistance.PersistanceManager.Shutdown();
        }
    }
}
