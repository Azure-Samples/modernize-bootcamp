using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    /// <summary>
    /// Server-side cart storage keyed by the browser's cart cookie. Replaces the System.Web
    /// session the MVC app used: a Blazor circuit has no <c>HttpContext</c>, so the cart cannot
    /// live in <c>HttpContext.Session</c> any more.
    /// </summary>
    public interface ICartStore
    {
        Cart Get(string key);
        void Save(string key, Cart cart);
        void Remove(string key);
    }
}
