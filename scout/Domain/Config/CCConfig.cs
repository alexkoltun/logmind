using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain.Config
{
    public class CCConfig : BaseCommunicationConfig
    {
        public string ClientId { get; set; }
        public string User { get; set; }
        public string Password { get; set; }
    }
}
