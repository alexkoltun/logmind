using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;

namespace Logmind.Interfaces
{
    public interface IPersistence : IRunable
    {
        void SaveConfigObject(Domain.ModulesTypes module, BaseConfig instance);

        T GetKey<T>(Domain.ModulesTypes module, string key);
        T GetObject<T>(Domain.ModulesTypes module) where T : BaseConfig, new();
    }
}
