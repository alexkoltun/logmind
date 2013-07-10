using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Domain;
using System.Threading;
using Logmind.Interfaces;
using System.Collections.Concurrent;
using Logmind.Domain.Requests;

namespace Logmind.DataDelivery
{
    public class Postman : ThreadBasedManager, IPostMan
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

        private Queue<MsgData> m_Packages = new Queue<MsgData>();
        private Guid m_LastMsgId = Guid.NewGuid();
        private DateTime m_LastDelivered = DateTime.Now;
        private object m_Sync = new object();

        private PostmanConfig m_Config;
        private DeliveryManager m_DeliveryMgr;
        private ManualResetEvent m_StopEvent;

        public Postman(ManualResetEvent stopEvent) 
        {
            m_StopEvent = stopEvent;
        }

        public void Init(PostmanConfig config, DeliveryManager deliveryMgr)
        {
            m_DeliveryMgr = deliveryMgr;
            m_Config = config;
            base.StartThread(new ThreadStart(SendingThreadMethod),m_StopEvent);
        }

        public void Enqueue(MsgData msg)
        {
            if (m_Packages.Count > m_Config.SizeThreshold)
            {
                lock (m_Sync)
                {
                    // avoid double processing
                    if (m_Packages.Count > m_Config.SizeThreshold)
                    {
                        var temp = m_Packages;

                        m_DeliveryMgr.ProcessQueue(temp);
                        m_LastDelivered = DateTime.Now;
                        m_Packages = new Queue<MsgData>();
                    }
                }
            }
            
            m_Packages.Enqueue(msg);
        }

        public void Shutdown()
        {
            //base.StopThread();
        }

        private void m_ConfigManager_ConfigurationReceived(object sender, ConfigEventArgs e)
        {
            if (e.NewConfig.PostMan != null)
            {
                m_Config = e.NewConfig.PostMan;
                base.StartThread(new ThreadStart(SendingThreadMethod),m_StopEvent);
            }
        }

        private void SendingThreadMethod()
        {
            // TODO... check last delivered...        
        }
    }
}
