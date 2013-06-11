using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using System.Threading;
using Logmind.Persistance;
using Logmind.Interfaces;
using Logmind.Domain;
using Logmind.CommandAndControl;

namespace Logmind.ConfigurationManager
{
    public class ConfigurationManager : ThreadBasedManager, IConfigurationManager
    {
        private IRunner m_Runner;
        private ConfigurationHolder m_Config;
        private object m_Sync = new object();

        private void PollingThreadMethod()
        {
            // start polling thread and try to fetch new configuration from the server..
            do
            {
                try
                {
                    DateTime lastConfigured = m_Runner.Persistence.GetKey<DateTime>(ModulesTypes.General, Constants.ConfigKeys.LastConfigured);

                    if (lastConfigured == DateTime.MinValue) // avoid json serilization errors
                    {
                        lastConfigured = DateTime.MinValue.ToUniversalTime();
                    }

                    var newConfig = m_Runner.Commander.GetConfig(lastConfigured);

                    if (newConfig != null)
                    {
                        LastConfig = newConfig;

                        m_Runner.Persistence.SaveConfigObject(ModulesTypes.General, newConfig.General);

                        if (ConfigurationReceived != null)
                        {
                            ConfigurationReceived(null, new ConfigEventArgs() { NewConfig = newConfig });
                        }
                    }
                }
                catch (Exception ex)
                {
                    // TODO, log...
                }
            } while (m_StopEvt.WaitOne(Constants.StopWaitInterval) == false);
        }

        public ConfigurationHolder LastConfig
        {
            get { lock (m_Sync) { return m_Config; } }
            private set { lock (m_Sync) { m_Config = value; } }
        }

        public void Shutdown()
        {
            base.StopThread();
        }
        public void Init(IRunner runner)
        {
            m_Runner = runner;
            // check that client is configured..
            // read uri endpoints + client id from configuration (post set-up)

            bool configured = m_Runner.Persistence.GetKey<bool>(Domain.ModulesTypes.General, Constants.ConfigKeys.IsConfigured);

            if (configured)
            {
                /*
                * read config form persistence layer
                * start polling thread and try to fetch new configuration from the server..
                */
                var config = new ConfigurationHolder();
                config.PostMan = m_Runner.Persistence.GetObject<PostmanConfig>(Logmind.Domain.ModulesTypes.DataDelivery);
                config.Communicaiton = m_Runner.Persistence.GetObject<BaseCommunicationConfig>(Logmind.Domain.ModulesTypes.Communication);

                LastConfig = config;
            }
            else
            {
                // read configuration from app.config..???
            }

            base.StartThread(new ThreadStart(this.PollingThreadMethod));
        }

        public event EventHandler<ConfigEventArgs> ConfigurationReceived;
    }
    

}
