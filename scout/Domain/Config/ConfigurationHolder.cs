using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain.Config
{
    public class ConfigurationHolder
    {
        public GeneralConfig General { get; set; }
        public PostmanConfig PostMan { get; set; }
        public BaseCommunicationConfig Communicaiton { get; set; }
    }
}
