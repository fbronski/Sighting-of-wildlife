using WildLifeBildBot.Model;
using MongoDB.Bson;
using MongoDB.Driver;
using SQLite.Framework;
using SQLite.Framework.Enums;
using SQLite.Framework.Extensions;
using System;
using System.Collections.Generic;
using System.Text;

namespace WildLifeBildBot.Core
{

        public class SqlLiteDataLayer<T> : IDisposable where T : class
        {
            public SQLiteDatabase sdb = null;
            public SQLiteTable<T> Collection { get; private set; }
            private bool disposed = false;
            public SqlLiteDataLayer(string dbname, bool dropbeforecreate = false)
            {
                SQLiteOptions options = new SQLiteOptionsBuilder($"{dbname}.db").UseMinimumSqliteVersion(SQLiteMinimumVersion.V3_36).Build();

                sdb = new(options);
                sdb.Schema.CreateTable<CameraSL>();
                sdb.Schema.CreateTable<UserSL>();
                sdb.Schema.CreateTable<FriendSL>();
                sdb.Schema.CreateTable<BildPostSL>();

                sdb.Schema.CreateIndex<CameraSL>(b => b.CameraName);
                sdb.Schema.CreateIndex<BildPostSL>(b => b.BildId);

        }

        public async Task DeleteTableCameraAndCreateNew()
        {
           
            if (sdb != null)
            {
                sdb.Schema.DropTable<CameraSL>();
                sdb.Schema.CreateTable<CameraSL>();
                sdb.Schema.CreateIndex<CameraSL>(b => b.CameraName);
            }
        }

        public async Task Save(BildPostSL obj)
        {
            SQLiteTable<BildPostSL> col = sdb.Table<BildPostSL>();//.ToLower());

           
            var query = col.AsQueryable().Where(c => c._id == obj._id);

            if (query.Count() == 0)
            {
              

                await col.AddAsync(obj);
            }
            else
            {
                await col.UpdateAsync(obj);
            }
        }
        public BildPostSL GetBildPost(string bildid)
        {

            SQLiteTable<BildPostSL> col = sdb.Table<BildPostSL>();

            var query = col.AsQueryable().Where(c => c.BildId == bildid);

            if (query == null)
                return null;

            if (query.Count() == 0)
                return null;

            if (query.Count() == 1)
                return query.Single();
            else
                return query.ToList()[0];

        }

        public async Task Save(CameraSL obj)
        {
            SQLiteTable<CameraSL> col = sdb.Table<CameraSL>();//.ToLower());


            var query = col.AsQueryable().Where(c => c._id == obj._id);

            if (query.Count() == 0)
            {


                await col.AddAsync(obj);
            }
            else
            {
                await col.UpdateAsync(obj);
            }
        }

        public CameraSL GetCameraByName(string camid)
        {

            SQLiteTable<CameraSL> col = sdb.Table<CameraSL>();//.ToLower());

            var query = col.AsQueryable().Where(c => c.CameraName == camid);

            if (query == null)
                return null;

            if (query.Count() == 0)
                return null;

            if (query.Count() == 1)
                return query.Single();
            else
                return query.ToList()[0];

        }

        #region IDisposable

        public void Dispose()
        {
            this.Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!this.disposed)
            {
                if (disposing)
                {
                    if (sdb != null)
                    {
                       
                    }
                }
            }

            this.disposed = true;
        }

        # endregion
    }
}
