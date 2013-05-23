using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Domain;
using System.Threading;
using Logmind.Interfaces;

namespace Logmind.DataDelivery
{
    public class Postman : ThreadBasedManager
    {
        private Queue<Package> m_Packages = new Queue<Package>();
        private Guid m_LastMsgId = Guid.NewGuid();
        private DateTime m_LastDelivered = DateTime.Now;

        private Thread m_SendingThread;
        private ManualResetEvent m_SendEvt;

        private IConfigurationManager m_ConfigManager;
        private PostmanConfig m_Config;

        public Postman() {}

        public void Init(IConfigurationManager configManager)
        {
            m_ConfigManager = configManager;
            m_ConfigManager.ConfigurationReceived += new EventHandler<ConfigEventArgs>(m_ConfigManager_ConfigurationReceived);

            var configHolder = m_ConfigManager.LastConfig;
            if (configHolder != null && configHolder.PostMan != null)
            {
                m_Config = configHolder.PostMan;
                base.StartThread(new ThreadStart(SendingThreadMethod));
            }
        }

        public void Shutdown()
        {
            base.StopThread();
        }
        private void m_ConfigManager_ConfigurationReceived(object sender, ConfigEventArgs e)
        {
            if (e.NewConfig.PostMan != null)
            {
                m_Config = e.NewConfig.PostMan;
                base.StartThread(new ThreadStart(SendingThreadMethod));
            }
        }

        private void SendingThreadMethod()
        {
            // TODO...         
        }
    }
}
