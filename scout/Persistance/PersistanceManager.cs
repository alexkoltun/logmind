using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Logmind.Interfaces;
using Logmind.Domain;
using System.Reflection;
using Logmind.Domain.Config;
using System.Data;
using System.ComponentModel;

namespace Logmind.Persistance
{
    public static class PersistanceManager
    {
        private static IPersistenceProvider m_Provider;

        #region privates
        /// <summary>
        /// factory method
        /// </summary>
        /// <returns></returns>
        private static IPersistenceProvider CreateProvider()
        {
            return new SqliteProvider();
        }

        private static bool TryConvert(string val, Type objType, out object retVal)
        {
            TypeConverter tc = TypeDescriptor.GetConverter(objType);

            if (tc.IsValid(val))
            {
                retVal = tc.ConvertFromString(val);
                return true;
            }

            retVal = null;
            return false;
        }

        #endregion

        public static void Init()
        {
            m_Provider = CreateProvider();
            m_Provider.Init();
        }

        public static void Shutdown()
        {
            m_Provider.Shutdown();
        }

        public static void SaveConfigObject(Domain.ModulesTypes module, BaseConfig instance)
        {
            if (instance == null)
                throw new ArgumentNullException("config object instance can't be null");

            string moduleName = module.ToString();
            var t = instance.GetType();

            var propertyInfos = t.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.FlattenHierarchy);

            foreach (var p in propertyInfos)
            {
                var propRawVal = t.InvokeMember(p.Name,
                             BindingFlags.Instance | BindingFlags.Public | BindingFlags.GetProperty,
                             null,
                             instance,
                             null);

                if (propRawVal != null)
                {
                    string propVal = propRawVal.ToString();
                    m_Provider.InsertOrUpdate(moduleName, p.Name, propVal);
                }
            }
        }

        public static T GetObject<T>(Domain.ModulesTypes module) where T : BaseConfig, new()
        {
            var table = m_Provider.GetModuleKeys(module.ToString());

            if (table != null)
            {
                var instance = new T();
                var realT = typeof(T);

                var propertyInfos = realT.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.FlattenHierarchy);
                Dictionary<string, PropertyInfo> propsMap = propertyInfos.ToDictionary(e => e.Name, e => e);

                foreach (DataRow dr in table.Rows)
                {
                    string keyName = (string)dr[m_Provider.KeyColumnName];

                    if (propsMap.ContainsKey(keyName))
                    {
                        var propInfo = propsMap[keyName];

                        string rawValue = (string)dr[m_Provider.ValueColumnName];
                        object convertedObj;
                        TryConvert(rawValue, propInfo.PropertyType, out convertedObj);

                        realT.InvokeMember(keyName,
                                BindingFlags.Instance | BindingFlags.Public | BindingFlags.SetProperty,
                                Type.DefaultBinder,
                                instance,
                                new object[] { convertedObj });
                    }
                }

                return instance;
            }

            return default(T);
        }
    }
}
