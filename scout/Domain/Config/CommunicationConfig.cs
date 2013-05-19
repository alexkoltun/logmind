using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Domain;

namespace Logmind.Domain.Config
{
    public class CommunicationConfig : BaseConfig
    {
        public string ChannelType { get; set; }
        public string ServerEndpoint { get; set; }
        public int PollingRate { get; set; }
        public int BlockSize { get; set; }
    }
}
