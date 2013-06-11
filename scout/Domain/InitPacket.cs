using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain
{
    public class InitPacket
    {
        public string Endpoint { get; set; }
        public string ClientId { get; set; }
        public string User { get; set; }
        public string Password { get; set; }
    }
}
