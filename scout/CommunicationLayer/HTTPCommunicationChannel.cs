using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net;
using System.IO;
using System.Threading;

namespace Logmind.CommunicationLayer
{
    public class HTTPCommunicationChannel
    {
        public string Url { get; set; }
        public bool IsTwoWay { get; set; }
        public TimeSpan PollingRate { get; set; }

        public delegate void onPacketDelegate (byte[] data, int start, int len);
        public event onPacketDelegate onPacket;

        private void fireOnPacket(byte[] data, int start, int len)
        {
            if (onPacket != null)
            {
                onPacket(data, start, len);
            }
        }

        private Thread _pollingThread;

        public HTTPCommunicationChannel()
        {
            IsTwoWay = true;
            PollingRate = TimeSpan.FromSeconds(15);
        }

        public void init()
        {
            if(IsTwoWay) 
            {
                _pollingThread = new Thread(pollingHandler);
                _pollingThread.Start();
            }

        }

        private void pollingHandler() 
        {

        }


        public void sendPacket(byte[] data, int start, int len)
        {

        }


        private byte[] sendRecvBlock(byte[] data, int start, int len, Guid blockId)
        {
            // TODO: cut the block to piceces
            MemoryStream buffer = new MemoryStream(1024*1024);

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(Url);
            request.Method = "POST";
            request.ContentType = "application/octet-stream";


            BinaryWriter binOut = new BinaryWriter(buffer);

            // BYTE[MESSAGE_TYPE - 0x1A], 16 BYTES[BLOCK ID GUID], 4 BYTES[LEN], BYTE[HEADER_END - 0xFF], LEN BYTES[PAYLOAD], BYTE[MESSAGE_END - 0xFF]
            binOut.Write((byte)0x1A);
            binOut.Write(blockId.ToByteArray());
            binOut.Write((int)len);
            binOut.Write((byte)0xFF);
            binOut.Write(data, start, len);
            binOut.Write((byte)0xFF);
            binOut.Flush();

            request.ContentLength = buffer.Length;

            Stream requestStream = request.GetRequestStream();
            buffer.WriteTo(requestStream);

            HttpWebResponse response = (HttpWebResponse)request.GetResponse();

            Stream responseStream = response.GetResponseStream();

            // TODO,
            return null;
            
        }

    }
}
