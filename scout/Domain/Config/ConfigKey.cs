using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain.Config
{
    public class ConfigKey : BaseConfig
    {
        public string KeyName { get; set; }
        public string Value { get; set; }
    }
}
