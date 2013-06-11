using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Domain;

namespace Logmind.Domain.Config
{
    // TODO, ignore json serialization on the type
    public class BaseCommunicationConfig : BaseConfig
    {
        public string RawUri { get; set; }

        public string ServerHost { get; set; }
        public int ServerPort { get; set; }
        public string ChannelType { get; set; }
        public string ServerEndpoint { get; set; }
        public int PollingRate { get; set; }
        public int BlockSize { get; set; }
    }
}
