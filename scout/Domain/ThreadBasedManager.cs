using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;

namespace Logmind.Domain
{
    public abstract class ThreadBasedManager
    {
        private Thread m_Thread;
        private ManualResetEvent m_StopEvt;

        protected void StartThread(ThreadStart threadMethod, ManualResetEvent stopEvent)
        {
            m_StopEvt = stopEvent;

            if (m_Thread != null && m_Thread.IsAlive)
            {
                m_Thread.Join(Constants.JoinOnThread);
            }

            m_Thread = new Thread(new ThreadStart(threadMethod));
            m_Thread.IsBackground = true;
            m_Thread.Start();
        }
    }
}
