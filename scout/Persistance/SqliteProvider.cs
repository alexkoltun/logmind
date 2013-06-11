using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Data.SQLite;
using Logmind.Interfaces;
using System.Data;

namespace Logmind.Persistance
{
    public class SqliteProvider : IPersistenceProvider
    {
        // REVIEW by AK
        // Please use Command.Parameters instead of string substitutions
        // Like this: 
        // SQLiteCommand cmd = new SQLiteCommand(query, connection);
        // cmd.Parameters.Add(new SQLiteParameter("@key", value);

        private const string DB_NAME = "scoutDb.db3";
        private const string CONN_TEMPLATE = "Data Source={0};FailIfMissing=False;Version=3";
        private const string CREATE_SETTING_TABLE = "CREATE TABLE IF NOT EXISTS [SettingConfig]([Module] NVARCHAR(100) NOT NULL ,[Key] NVARCHAR(255) NOT NULL ,[Value] NVARCHAR(2048) NULL); CREATE UNIQUE INDEX pk_SettingConfig ON [SettingConfig] ([Module],[Key]);";
        private const string INSERT_REPLACE = "INSERT OR REPLACE INTO [SettingConfig] ([Module],[Key],[Value]) VALUES ('{0}','{1}','{2}');";
        private const string SELECT_MODULE_CONFIG = "SELECT * FROM [SettingConfig] WHERE [Module] = '{0}';";
        private const string SELECT_SPECIFIC_KEY = "SELECT [Value] FROM [SettingConfig] WHERE [Module] = '{0}' AND [Key] = '{1}';";

        private const string VAL_COl_NAME = "Value";
        private const string KEY_COl_NAME = "Key";

        //private SQLiteConnection m_Connection;

        private string GetDbFile()
        {
            string folder = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);

            return Path.Combine(folder, DB_NAME);
        }

        

        private SQLiteConnection GetConnection()
        {
            string conStr = string.Format(CONN_TEMPLATE, DB_NAME);
            return new SQLiteConnection(conStr);
        }

        private void CreateDB()
        {
            string dbFile = GetDbFile();

            if (File.Exists(dbFile) == false)
            {
                SQLiteConnection.CreateFile(dbFile);

                using (var con = GetConnection())
                {
                    SQLiteCommand command = new SQLiteCommand(CREATE_SETTING_TABLE, con);
                    command.ExecuteNonQuery();
                }
            }
        }

        public void Init()
        {
            CreateDB();
        }
        public void Shutdown()
        {
            //if (m_Connection != null && m_Connection.State != System.Data.ConnectionState.Closed)
            //{
            //    m_Connection.Close();
            //    m_Connection = null;
            //}
        }

        public void InsertOrUpdate(string module, string key, string val)
        {
          
            string sql = string.Format(INSERT_REPLACE, module, key, val);

            using (var con = GetConnection())
            {
                con.Open();
                SQLiteCommand command = new SQLiteCommand(sql, con);
                command.ExecuteNonQuery();
            }
        }

        public DataTable GetModuleKeys(string module)
        {
            string sql = string.Format(SELECT_MODULE_CONFIG,module);
            DataSet ds = new DataSet();

            using (var con = GetConnection())
            {
                con.Open();
                SQLiteDataAdapter adapter = new SQLiteDataAdapter(sql, con);
                adapter.Fill(ds);
            }

            // check that DB returned something..
            if (ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                return ds.Tables[0];

            return null;
        }

        public string ValueColumnName
        {
            get { return VAL_COl_NAME; }
        }
        public string KeyColumnName
        {
            get { return KEY_COl_NAME; }
        }

        public string GetModuleKey(string module, string key)
        {
            string sql = string.Format(SELECT_SPECIFIC_KEY, module,key);

            using (var con = GetConnection())
            {
                con.Open();
                SQLiteCommand command = new SQLiteCommand(sql, con);
                var reader = command.ExecuteReader(CommandBehavior.SingleRow | CommandBehavior.SequentialAccess);

                if (reader != null && reader.HasRows)
                {
                    var res = reader.GetString(0);

                    reader.Close();
                    return res;
                }
            }

            return null;
            
        }
    }
}
