using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Harvester
{
    public class BaseHarvester
    {
        protected List<ConfigKey> m_Config;

        public virtual void Init(List<ConfigKey> config)
        {
            m_Config = config;
        }

        public abstract void Do();
    }
}
