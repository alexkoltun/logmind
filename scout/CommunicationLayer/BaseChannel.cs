using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Interfaces;
using System.Threading;

namespace Logmind.CommunicationLayer
{
    public abstract class BaseChannel : ICommunicationChannel
    {
        protected Domain.Config.BaseCommunicationConfig m_Config;
        protected ManualResetEvent m_StopEvent;

        protected const int STOP_WAIT = 20;

        #region ICommunicationChannel Members

        public virtual void Init(Domain.Config.BaseCommunicationConfig config)
        {
            m_Config = config;
            m_StopEvent = new ManualResetEvent(false);
        }
        
        public abstract void ShutDown();
        public abstract void Send(byte[] packetData);

        public string Url { get;set;}
        public bool IsTwoWay { get;set;}
        
        public event OnPacketDelegate OnPacket = null;

        #endregion

        protected void FireOnPacket(byte[] data, int start, int len)
        {
            if (OnPacket != null)
                OnPacket(data, start, len);
        }
    }
}
