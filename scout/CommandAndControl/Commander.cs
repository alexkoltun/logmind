using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Interfaces;

namespace Logmind.CommandAndControl
{
    public class Commander : ICommandAndControl
    {
        private CCConfig m_Config;
        private IRunner m_Runner;

        public void Init(IRunner runner)
        {
            m_Runner = runner;
            m_Config = m_Runner.GetCCConfig();
        }

        public ConfigurationHolder GetConfig() 
        {
            return null;
        }

        public void Shutdown()
        {
            // do nop  
        }

        
    }
}
