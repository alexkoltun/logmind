using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Interfaces
{
    //public delegate void OnConfigurationReceived(object sender,);

    public interface IConfigurationManager : IRunable
    {
        event EventHandler<ConfigEventArgs> ConfigurationReceived;
        ConfigurationHolder LastConfig { get; }
    }
}
