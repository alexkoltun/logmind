using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Domain;
using Logmind.Interfaces;

namespace Logmind.Runner
{
    internal class ProcessController : IRunner
    {
        private  IConfigurationManager m_ConfigManager;
        private IPersistence m_Persistence;
        private ICommandAndControl m_Cc;

        Logmind.DataDelivery.Postman m_PostMan;

        private List<IRunable> m_Runnables;

        internal ProcessController()
        {
            m_Runnables = new List<IRunable>();

            m_Persistence = new Persistance.PersistanceManager();
            m_Runnables.Add(m_Persistence);

            m_Cc = new CommandAndControl.Commander();
            m_Runnables.Add(m_Cc);

            m_ConfigManager = new ConfigurationManager.ConfigurationManager();
            m_Runnables.Add(m_ConfigManager);
        }


        internal void Run()
        {
            m_Persistence.Init(this);
            m_Cc.Init(this);
            m_ConfigManager.Init(this);

            //
            m_PostMan = new DataDelivery.Postman();
            m_PostMan.Init(m_ConfigManager);

            //PostmanConfig testC = new PostmanConfig() { SizeThreshold = 500, TimeThreshold = 500 };

            // Persistance.PersistanceManager.SaveConfigObject(Domain.ModulesTypes.DataDelivery, testC);
        }

        internal void Shutdown()
        {
            foreach (var runable in m_Runnables)
            {
                runable.Shutdown();
            }
            m_PostMan.Shutdown();
        }


        public CCConfig GetCCConfig()
        {
            string ccUri = System.Configuration.ConfigurationManager.AppSettings[Constants.ConfigKeys.CCUri];
            if (string.IsNullOrEmpty(ccUri))
                throw new ArgumentNullException(Constants.ConfigKeys.CCUri, "key cannot be NULL or Empty");

            var clientId = System.Configuration.ConfigurationManager.AppSettings[Constants.ConfigKeys.ClientId];
            if (string.IsNullOrEmpty(clientId))
                throw new ArgumentNullException(Constants.ConfigKeys.ClientId, "key cannot be NULL or Empty");

            var config = Utils.ParseUri<CCConfig>(ccUri);
            config.ClientId = clientId;

            return config;
        }

        public IConfigurationManager ConfigManager
        {
            get { return m_ConfigManager; }
        }

        public IPersistence Persistence
        {
            get { return m_Persistence; }
        }

        public ICommandAndControl Commander
        {
            get { return m_Cc; }
        }
    }
}
