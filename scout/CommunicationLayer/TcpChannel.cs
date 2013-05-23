using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net;
using System.Net.Sockets;
using System.Threading;

namespace Logmind.CommunicationLayer
{
    public class TcpChannel : BaseChannel
    {
        private TcpClient m_Client;

        private Thread m_ReceiveThread;

        public override void Init(Domain.Config.BaseCommunicationConfig config)
        {
            base.Init(config);

            // TODO, init TCP client..

            m_ReceiveThread = new Thread(new ThreadStart(ReceiveThreadMethod));
            m_ReceiveThread.IsBackground = true;
            m_ReceiveThread.Start();

        }

        public override void ShutDown()
        {
            //throw new NotImplementedException();
        }

        private void ReceiveThreadMethod()
        {
            try
            {
                while (m_StopEvent.WaitOne(STOP_WAIT, false) == false)
                {
                    //m_Client.ge
                }
            }
            catch (Exception ex)
            {
                //TOOD
            }
        }
    }
}
