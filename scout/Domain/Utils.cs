using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Domain
{
    public static class Utils
    {
        public static T ParseUri<T>(string rawUri) where T : BaseCommunicationConfig, new()
        {
            //e.g. "tcp://127.0.0.1:5000/config"
            var uri = new Uri(rawUri);

            T config = new T();
            config.RawUri = rawUri;

            config.ServerHost = uri.Host;
            config.ChannelType = uri.Scheme;
            config.ServerPort = uri.Port;
            config.ServerEndpoint = uri.LocalPath;

            return config;
        }
    }
}
