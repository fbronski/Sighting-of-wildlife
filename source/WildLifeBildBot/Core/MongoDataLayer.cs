using System;
using System.Configuration;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Microsoft.Win32.SafeHandles;
using MongoDB.Driver;
using MongoDB.Driver.GridFS;
using MongoDB.Bson;
using System.IO;
using MongoDB.Driver.Core;
using System.Linq.Expressions;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using WildLifeBildBot.Model;

namespace WildLifeBildBot.Core
{
    

    public interface IRepository : IDisposable
    {
        void Delete<T>(Expression<Func<T, bool>> expression) where T : class, new();
        void Delete<T>(T item) where T : class, new();
        void DeleteAll<T>() where T : class, new();
        T Single<T>(Expression<Func<T, bool>> expression) where T : class, new();
        System.Linq.IQueryable<T> All<T>() where T : class, new();
        System.Linq.IQueryable<T> All<T>(int page, int pageSize) where T : class, new();
        void Add<T>(T item) where T : class, new();
        void Add<T>(IQueryable<T> items) where T : class, new();
    }

    /// <summary>
    /// Mongo Datalyer Class basesd on Collectiontype name
    /// </summary>
    /// <typeparam name="T"></typeparam>
    public class MongoDataLayer<T> : IDisposable where T : class
    {

        public IMongoCollection<T> Collection { get; private set; }
        public IMongoDatabase database;
        private MongoServerAddress mongoServer = null;
        //private readonly GridFSBucket gridFs;
        private bool disposed = false;


        
        public MongoDataLayer(string servername, string mongodbname, bool dropbeforecreate = false)
        {
            var credential = MongoCredential.CreateCredential("xxxxxxxxx", "xxxxxxxxxxx", "xxxxxxxxxxxx");
            string cnn = $"mongodb://xxxxxxxx:xxxxxxxxxx@{servername}/?authMechanism=SCRAM-SHA-256&authSource=admin&replicaSet=afars-01";

            
            var dbname = mongodbname; // ConfigurationManager.ConnectionStrings["MongoDB"].ConnectionString;
            var client = new MongoClient(cnn);
           
            database = client.GetDatabase(dbname); //mongoServer.GetDatabase(dbname);
            Collection = database.GetCollection<T>(typeof(T).Name + "s");//.ToLower());

            if (dropbeforecreate == true)
                database.DropCollection(typeof(T).Name + "s");// Collection.Drop();

          
        }

        public async Task<List<T>> GetAllObjects()
        {
            return await Collection.Find(new BsonDocument()).ToListAsync();
        }

        public async Task<List<T>> GetObjectByField(string fieldName, string fieldValue)
        {
            var filter = Builders<T>.Filter.Eq(fieldName, fieldValue);
            var result = await Collection.Find(filter).ToListAsync();
            return result;
        }

        public async Task<long> GetObjectCountByField(string fieldName, string fieldValue)
        {
            var filter = Builders<T>.Filter.Eq(fieldName, fieldValue);
            var result = await Collection.CountDocumentsAsync(filter); //.ToListAsync();
            return result;
        }

        public async Task Save(BildPost obj)
        {
            IMongoCollection<BildPost> col = database.GetCollection<BildPost>(typeof(BildPost).Name + "s");//.ToLower());

            var filter = Builders<BildPost>.Filter.Eq("_id", obj._id);//
            var result = col.Find(filter).ToList();
           
            if (result.Count == 0)
            {
                obj._id = ObjectId.GenerateNewId().ToString();

                await col.InsertOneAsync(obj);
            }
            else
            {
                await col.ReplaceOneAsync(filter, obj);
            }
        }

        public Camera GetCameraByName(string camid)
        {

            IMongoCollection<Camera> col = database.GetCollection<Camera>(typeof(Camera).Name + "s");//.ToLower());

            var query = col.AsQueryable().Where(c => c.CameraName == camid );

            if (query == null)
                return null;

            if (query.Count() == 0)
                return null;

            if (query.Count() == 1)
                return query.Single();
            else
                return query.ToList()[0];

        }

        public BildPost GetBildPost(string bildid)
        {

            IMongoCollection<BildPost> col = database.GetCollection<BildPost>(typeof(BildPost).Name + "s");//.ToLower());

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
        public IEnumerable<BildPost> GetBildPost( int count, int skip = 0)
        {
            IMongoCollection<BildPost> col = database.GetCollection<BildPost>(typeof(BildPost).Name + "s");//.ToLower());

         
            var query = col.AsQueryable<BildPost>().OrderByDescending(c => c.UploadTime).Skip(skip).Take(count);
           
            var l = query.ToList();

            return l;
        }

        public int GetImageCount()
        {
            IMongoCollection<BildPost> col = database.GetCollection<BildPost>(typeof(BildPost).Name + "s");//.ToLower());

                var res = col.AsQueryable<BildPost>().OrderByDescending(c => c.UploadTime).Count();

                return res;
         

        }

        public async Task<List<T>> GetBildPostsByBetweenDates(string CamName, DateTime start, DateTime End)
        {
           
            var filter = Builders<T>.Filter.And(Builders<T>.Filter.Gte("UploadTime", start), Builders<T>.Filter.Lte("UploadTime",End ), Builders<T>.Filter.Eq("CameraName", CamName));
            var result = await Collection.Find(filter).ToListAsync();
            return result;
        }

        public async Task<List<T>> GetBildPostsByChattIDBetweenDates(string ChatId, DateTime start, DateTime End)
        {
           
            var filter = Builders<T>.Filter.And(Builders<T>.Filter.Gte("UploadTime", start), Builders<T>.Filter.Lte("UploadTime", End), Builders<T>.Filter.Eq("ChatId", ChatId));
            var result = await Collection.Find(filter).ToListAsync();
            return result;
        }

        public async Task<List<T>> GetObjects(int startingFrom, int count)
        {
            var result = await Collection.Find(new BsonDocument())
                                               .Skip(startingFrom)
                                               .Limit(count)
                                               .ToListAsync();
            return result;
        }

        public async Task<bool> Update(ObjectId id, string udateFieldName, string updateFieldValue)
        {
            var filter = Builders<T>.Filter.Eq("_id", id);
            var update = Builders<T>.Update.Set(udateFieldName, updateFieldValue);

            var result = await Collection.UpdateOneAsync(filter, update);

            return result.ModifiedCount != 0;
        }

        public async Task<bool> UpdateSert(ObjectId id, string udateFieldName, string updateFieldValue)
        {
            var upsertoptions = new UpdateOptions { IsUpsert = true };
            var filter = Builders<T>.Filter.Eq("_id", id);
            var update = Builders<T>.Update.Set(udateFieldName, updateFieldValue);

            var result = await Collection.UpdateOneAsync(filter, update, upsertoptions);

            return result.ModifiedCount != 0;
        }

        public async Task<bool> DeleteById(ObjectId id)

        {
            var filter = Builders<T>.Filter.Eq("_id", id);
            var result = await Collection.DeleteOneAsync(filter);
            return result.DeletedCount != 0;

        }
        

        public async Task<long> DeleteAllUsers()
        {
            var filter = new BsonDocument();
            var result = await Collection.DeleteManyAsync(filter);
            return result.DeletedCount;
        }

        public void CreateIndex(string fieldname, string indexname, bool unique=false)
        {
            
            var keys = Builders<T>.IndexKeys.Ascending(fieldname);
           
            CreateIndexOptions options = new CreateIndexOptions();
            options.Name = indexname;
            options.Unique = unique;
           
         
            Collection.Indexes.CreateOne(keys, options); //CreateIndex(keys, options);

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
                    if (mongoServer != null)
                    {
                       
                    }
                }
            }

            this.disposed = true;
        }

        # endregion

    }


}