using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Interfaces;
using Logmind.Domain.Requests;
using Logmind.Domain;
using System.Threading;

namespace Logmind.CommandAndControl
{
    public class Commander : ICommandAndControl
    {
        private CCConfig m_Config;
        private IRunner m_Runner;
        private ICommunicationChannel m_Chanel;
        private ManualResetEvent m_SyncEvt;

        private ConfigurationHolder m_LastConfig;

        public void Init(IRunner runner)
        {
            m_Runner = runner;
            m_Config = m_Runner.GetCCConfig();

            m_SyncEvt = new ManualResetEvent(false);

            // create and assume the channel alreasdy init
            m_Chanel = CommunicationLayer.Communicator.CreateChannel(m_Config);
            m_Chanel.OnPacket += new OnPacketDelegate(m_Chanel_OnPacket);
        }

        void m_Chanel_OnPacket(byte[] data, int start, int len)
        {
            try
            {
                var response = Utils.Deserialize<Package<ConfigurationHolder>>(data, start, len);

                // assume the buffer is all the packet data, let communication channel 
                // deal with partial packets..

                if (response != null)
                {
                    m_LastConfig = response.Payload;
                }

                m_SyncEvt.Set();
            }
            catch (Exception ex)
            {
                // TODO, log
                Console.WriteLine(ex.ToString());
            }
        }

        public ConfigurationHolder GetConfig(DateTime lastConfigured) 
        {
            Package<GetConfigRequest> request = new Package<GetConfigRequest>();

            request.Id = Guid.NewGuid().ToString();
            request.Type = Constants.Requests.GetConfig;

            request.Payload = new GetConfigRequest();
            request.Payload.LastConfigured = lastConfigured;
            request.Payload.Client = m_Config;
            
            byte[] buffer = Utils.Serialize<Package<GetConfigRequest>>(request);

            m_Chanel.Send(buffer);

            // wait here, is that a good enough solution..
            // anyway, wait with timeout...
            m_SyncEvt.WaitOne();

            return m_LastConfig;
        }

        public void Shutdown()
        {
            // do nop 
        }

        
    }
}
