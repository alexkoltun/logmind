using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain;
using System.Data;

namespace Logmind.Interfaces
{
    public interface IPersistenceProvider
    {
        void Init();
        void Shutdown();

        void InsertOrUpdate(string module, string key, string val);
        DataTable GetModuleKeys(string module);
        string ValueColumnName { get; }
        string KeyColumnName { get; }
    }
}
