using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Logmind.Interfaces
{
    public interface IRunable
    {
        void Init(IRunner runner);
        void Shutdown();
    }
}
