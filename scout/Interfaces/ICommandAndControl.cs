using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Interfaces
{
    public interface ICommandAndControl : IRunable
    {
        ConfigurationHolder GetConfig(DateTime lastConfigured);
    }
}
