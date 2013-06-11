using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain
{
    public class Constants
    {
        public const int StopWaitInterval = 30000; // 30 seconds
        public const int JoinOnThread = 1000; // 1 second

        public class ChannelType
        {
            public const string Tcp = "tcp";
            public const string Http = "http";
        }

        public class ConfigKeys
        {
            public const string ClientId = "Client.Id";
            /// <summary>
            /// command and control
            /// </summary>
            public const string CCUri = "CC.Uri";

            public const string IsConfigured = "IsConfigured";
            public const string LastConfigured = "LastConfigured";

        }

        public class Requests
        {
            public const string GetConfig = "GetConfig";
            public const string SendData = "SendData";
        }
    }
}
