using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Domain.Config;
using System.IO;
using System.Runtime.Serialization.Json;
using System.Web.Script.Serialization;

namespace Logmind.Domain
{
    public static class Utils
    {
        public static T ParseUri<T>(string rawUri) where T : BaseCommunicationConfig, new()
        {
            //e.g. "tcp://127.0.0.1:5000/config"
            var uri = new Uri(rawUri);

            T config = new T();
            config.RawUri = rawUri;

            config.ServerHost = uri.Host;
            config.ChannelType = uri.Scheme;
            config.ServerPort = uri.Port;
            config.ServerEndpoint = uri.LocalPath;

            return config;
        }

        public static byte[] Serialize<T>(T objInstance) where T : class
        {
            using (var ms = new MemoryStream())
            {
                var serializer = new DataContractJsonSerializer(typeof(T));
                serializer.WriteObject(ms, objInstance);

                return ms.ToArray();
            }
        }
      
        public static T Deserialize<T>(byte[] objBuffer) where T : class
        {
            if (objBuffer != null)
            {
                using (var stream = new MemoryStream(objBuffer))
                {
                    var serializer = new DataContractJsonSerializer(typeof(T));
                    return (T)serializer.ReadObject(stream);
                }
            }

            return default(T);
        }

        public static T Deserialize<T>(byte[] objBuffer,int index,int count) where T : class
        {
            if (objBuffer != null)
            {
                using (var stream = new MemoryStream(objBuffer,index,count))
                {
                    var serializer = new DataContractJsonSerializer(typeof(T));
                    return (T)serializer.ReadObject(stream);
                }
            }

            return default(T);
        }

        //public static byte[] Serialize<List<T>>(List<T> objInstance) //1
        ////where T :
        //{
        //    return null;    
        //}
    }
}
