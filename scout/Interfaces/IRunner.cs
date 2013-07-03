using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using System.Threading;

namespace Logmind.Interfaces
{
    public interface IRunner
    {
        IConfigurationManager ConfigManager { get; }
        IPersistence Persistence { get; }
        ICommandAndControl Commander { get; }
         
        CCConfig GetCCConfig();

        ManualResetEvent StopEvent { get; }
    }
}
