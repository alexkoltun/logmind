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
        private NetworkStream m_Stream;
        private Thread m_ReceiveThread;

        public override void Init(Domain.Config.BaseCommunicationConfig config)
        {
            base.Init(config);

            m_Client = new TcpClient();
            //m_Client.bl
            // TODO, what if failed?
            // start reconnect thread..
            m_Client.Connect(config.ServerHost, config.ServerPort);

            m_Stream = m_Client.GetStream();

            Console.WriteLine("client connected");

            m_ReceiveThread = new Thread(new ThreadStart(ReceiveThreadMethod));
            m_ReceiveThread.IsBackground = true;
            m_ReceiveThread.Start();
        }

        public override void Send(byte[] packetData)
        {
            if (m_Client.Connected)
            {
                m_Stream.Write(packetData, 0, packetData.Length);

                Console.WriteLine("sent packet");

            }
            else
            {
                // TOD
            }
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
                    if (m_Client.Available > 0)
                    {
                        byte[] receivedBuffer = new byte[m_Client.Available];

                        m_Stream.Read(receivedBuffer, 0, m_Client.Available);
                        this.FireOnPacket(receivedBuffer, 0, receivedBuffer.Length);
                    }

                }
            }
            catch (Exception ex)
            {
                //TOOD log
                Console.WriteLine(ex.ToString());
            }
        }
    }
}
