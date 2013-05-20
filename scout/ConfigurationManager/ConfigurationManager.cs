using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using System.Threading;
using Logmind.Persistance;
using Logmind.Interfaces;

namespace Logmind.ConfigurationManager
{
    public class ConfigurationManager : IConfigurationManager
    {
        private ConfigurationHolder m_Config;
        private object m_Sync = new object();

        private Thread m_Thread;
        private ManualResetEvent m_StopEvt;

        private void PollingThreadMethod()
        {
            // start polling thread and try to fetch new configuration from the server..
        }


        /*
         * get new configuration from the server, persist it, and invoke on configuration event for all the clients..
         * 
         */


        public ConfigurationHolder GetConfiguration
        {
            get { lock (m_Sync) { return m_Config; } }
            private set { lock (m_Sync) { m_Config = value; } }
        }


        public void Init()
        {

            var config = new ConfigurationHolder();
            config.PostMan = PersistanceManager.GetObject<PostmanConfig>(Logmind.Domain.ModulesTypes.DataDelivery);
            config.Communicaiton = PersistanceManager.GetObject<CommunicationConfig>(Logmind.Domain.ModulesTypes.Communication);


            GetConfiguration = config;
            /*
             * read config form persistence layer
             * start polling thread and try to fetch new configuration from the server..
             */
        }

       

        public event EventHandler<ConfigEventArgs> ConfigurationReceived;


    }
    

}
