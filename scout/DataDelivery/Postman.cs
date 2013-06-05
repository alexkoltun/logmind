using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Domain;
using System.Threading;
using Logmind.Interfaces;
using System.Collections.Concurrent;

namespace Logmind.DataDelivery
{
    public class Postman
    {
        // REVIEW by AK
        // Let's make sure we keep thread safty in mind (if relvant for this queue), if only one thread reads and writes to this queue that its fine
        // but if one thread writes and another reads please keep in mind this:
        // A Queue<T> can support multiple readers concurrently, as long as the collection is not modified. 
        // Even so, enumerating through a collection is intrinsically not a thread-safe procedure. 
        // To guarantee thread safety during enumeration, you can lock the collection during the entire enumeration. 
        // To allow the collection to be accessed by multiple threads for reading and writing, you must implement your own synchronization.
        // So maybe ConcurrentQueue or BlockingCollection<ConcurrentQueue> will be useful here, http://msdn.microsoft.com/en-us/library/ff963548.aspx
        //
        // In general a good implementation might be as following (didn't chek if it works):
        // 
        /*
        class QueueProcessor<T>
        {
            private bool _alive;
            private int _threadsInPool = 1;
            private int _timeThreashold = 1000;
            private ConcurrentQueue<T> _queue = new ConcurrentQueue<T>();
            private ConcurrentQueue<ConcurrentQueue<T>> _toProcess = new ConcurrentQueue<ConcurrentQueue<T>>();
            private List<Thread> _threads = new List<Thread>();
            private int _sizeThreshold = 100;

            public QueueProcessor()
            {
                // create threads
                for (int i = 0; i < _threadsInPool; i++)
                {
                    Thread worker = new Thread(Worker);
                    _threads.Add(worker);
                }

                // start them
                foreach (Thread thread in _threads)
                {
                    thread.Start();
                }
            }

            public void AddItem(T item)
            {
                if (_queue.Count > _sizeThreshold)
                {
                    lock (this)
                    {
                        // avoid double processing
                        if (_queue.Count > _sizeThreshold)
                        {
                            _toProcess.Enqueue(_queue);
                            // new queue
                            _queue = new ConcurrentQueue<T>();

                            // notify about this
                            Monitor.Pulse(this);
                        }
                    }
                }

                _queue.Enqueue(item);
            }

            void Worker()
            {
                while (_alive)
                {
                    ConcurrentQueue<T> items;
                    _toProcess.TryDequeue(out items);
                    
                    if(items == null) 
                    {
                        lock (this)
                        {
                            _toProcess.TryDequeue(out items);

                            if(items == null) 
                            {
                                Monitor.Wait(this, _timeThreashold);
                            }
                        }
                    }
         
                    
                    if (items != null)
                    {
                        Process(items);
                    }
                }
            }

            void Process(ConcurrentQueue<T> items)
            {
                // Send them out!
            }
        }

        */

        private Queue<Package> m_Packages = new Queue<Package>();
        private Guid m_LastMsgId = Guid.NewGuid();
        private DateTime m_LastDelivered = DateTime.Now;

        private Thread m_SendingThread;
        private ManualResetEvent m_SendEvt;

        private IConfigurationManager m_ConfigManager;
        private PostmanConfig m_Config;

        public Postman() {}

        public void Init(IConfigurationManager configManager)
        {
            m_ConfigManager = configManager;
            m_ConfigManager.ConfigurationReceived += new EventHandler<ConfigEventArgs>(m_ConfigManager_ConfigurationReceived);

            var configHolder = m_ConfigManager.GetConfiguration;
            if (configHolder != null && configHolder.PostMan != null)
            {
                m_Config = configHolder.PostMan;
                RestartSendingThread();
            }
        }

        private void m_ConfigManager_ConfigurationReceived(object sender, ConfigEventArgs e)
        {
            if (e.NewConfig.PostMan != null)
            {
                m_Config = e.NewConfig.PostMan;
                RestartSendingThread();
            }
        }


        private void RestartSendingThread()
        {
            if (m_SendingThread != null && m_SendingThread.IsAlive)
            {
                m_SendingThread.Join(1000);
            }

            m_SendingThread = new Thread(new ThreadStart(SendingThreadMethod));
            m_SendingThread.IsBackground = true;
            m_SendingThread.Start();
        }

        private void SendingThreadMethod()
        {
            // TODO...         
        }
    }
}
