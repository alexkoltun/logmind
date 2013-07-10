using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Interfaces;
using System.Threading;

namespace Logmind.Harvester
{
    public abstract class BaseHarvester : IHarvester
    {
        protected string m_Id;
        protected List<ConfigKey> m_Config;
        protected IPostMan m_PostMan;
        protected ManualResetEvent m_StopEvent;

        public virtual void Init(string id, List<ConfigKey> config, IPostMan postMan, ManualResetEvent stopEvent)
        {
            m_Id = id;
            m_Config = config;
            m_PostMan = postMan;
            m_StopEvent = stopEvent;
        }

        public abstract void Do();
    }
}
