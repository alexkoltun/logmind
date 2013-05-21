using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Domain;

namespace Logmind.Domain.Config
{
    public class PostmanConfig : BaseConfig
    {
        public int SizeThreshold { get; set; }
        public int TimeThreshold { get; set; }
    }
}
