using System.Web;

namespace eShopLite.StoreFx.Services
{
    public interface ISessionStore
    {
        T Get<T>(string key) where T : class;
        void Set<T>(string key, T value) where T : class;
        void Remove(string key);
    }

    /// <summary>
    /// The only place that touches HttpContext.Current. Porting to ASP.NET Core means
    /// replacing this one class with an IHttpContextAccessor/ISession implementation.
    /// </summary>
    public class HttpContextSessionStore : ISessionStore
    {
        public T Get<T>(string key) where T : class
        {
            return HttpContext.Current?.Session?[key] as T;
        }

        public void Set<T>(string key, T value) where T : class
        {
            var session = HttpContext.Current?.Session;
            if (session != null)
            {
                session[key] = value;
            }
        }

        public void Remove(string key)
        {
            HttpContext.Current?.Session?.Remove(key);
        }
    }
}
