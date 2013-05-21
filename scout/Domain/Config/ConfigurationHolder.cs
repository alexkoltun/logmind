using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain.Config
{
    public class ConfigurationHolder
    {
        public PostmanConfig PostMan { get; set; }
        public CommunicationConfig Communicaiton { get; set; }

    }
}
