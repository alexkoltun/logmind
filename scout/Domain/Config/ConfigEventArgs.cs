using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain.Config
{
    public class ConfigEventArgs : EventArgs
    {
        public ConfigurationHolder NewConfig { get; set; }
    }
}
