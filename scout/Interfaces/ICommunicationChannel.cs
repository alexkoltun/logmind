using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Interfaces
{
    public delegate void OnPacketDelegate(byte[] data, int start, int len);

    public interface ICommunicationChannel
    {
        void Init(BaseCommunicationConfig config);
        void Send(byte[] packetData);
        void ShutDown();

        string Url { get; set; }
        bool IsTwoWay { get; set; }

        event OnPacketDelegate OnPacket;    
    }
}
