using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain.Config
{
    public class HarvesterConfig : BaseConfig
    {
        public string Id { get; set; }
        public string Type { get; set; }

        public List<ConfigKey> Parameters { get; set; }
    }
}
