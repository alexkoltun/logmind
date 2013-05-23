using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using Logmind.Interfaces;
using Logmind.Domain;

namespace Logmind.CommunicationLayer
{
    public class Communicator
    {
        ICommunicationChannel m_Channel = null;

        public void Init(BaseCommunicationConfig config)
        {
            // create and init com channel..

        }

        public void ShutDown()
        {
            m_Channel.ShutDown();
        }



        public ICommunicationChannel CreateChannel(BaseCommunicationConfig config)
        {
            ICommunicationChannel newChannel = null;

            switch (config.ChannelType)
            {
                case Constants.ChannelType.Tcp:
                    newChannel = new TcpChannel();
                    break;
                default:
                    throw new ArgumentException(string.Format("unknown channel type: {0}",config.ChannelType));
            }

            newChannel.Init(config);

            return newChannel;
        }
    }
}
