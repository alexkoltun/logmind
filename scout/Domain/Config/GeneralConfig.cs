using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Domain.Config
{
    public class GeneralConfig : BaseConfig
    {
        public DateTime LastConfigured { get; set; }
    }
}
