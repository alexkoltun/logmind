using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Domain.Requests
{
    public class GetConfigRequest
    {
        public DateTime LastConfigured { get; set; }
        public CCConfig Client { get; set; }

    }
}
