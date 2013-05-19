using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Interfaces;

namespace CommunicationLayer
{
    public class Communicator
    {
        ICommunicationChannel m_Channel = null;

        public void Init(CommunicationConfig config)
        {
            // create and init com channel..

        }

        public void ShutDown()
        {
            m_Channel.ShutDown();
        }

        public ICommunicationChannel Channel
        {
            get { return m_Channel; }
        }
    }
}
