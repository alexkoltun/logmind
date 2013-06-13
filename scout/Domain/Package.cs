using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Domain;

namespace Logmind.Domain
{
    public class Package<T> : Base
    {
        public string Id { get; set; }
        public string Type { get; set; }

        public T Payload { get; set; }
    }
}
