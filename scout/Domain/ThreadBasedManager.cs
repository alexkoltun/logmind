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
        protected ManualResetEvent m_StopEvt;

        protected void StopThread()
        {
            m_StopEvt.Set();
        }

        protected void StartThread(ThreadStart threadMethod)
        {
            if (m_Thread != null && m_Thread.IsAlive)
            {
                m_Thread.Join(Constants.JoinOnThread);
            }

            m_StopEvt = new ManualResetEvent(false);
            m_Thread = new Thread(new ThreadStart(threadMethod));
            m_Thread.IsBackground = true;
            m_Thread.Start();
        }
    }
}
