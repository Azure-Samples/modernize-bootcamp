using System;

using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    public interface ICartService
    {
        Cart GetCart();
        void Save(Cart cart);
        void Clear();
    }

    public class SessionCartService : ICartService
    {
        public const string SessionKey = "eShopLite.Cart";

        private readonly ISessionStore _session;

        public SessionCartService(ISessionStore session)
        {
            _session = session ?? throw new ArgumentNullException(nameof(session));
        }

        public Cart GetCart()
        {
            var cart = _session.Get<Cart>(SessionKey);
            if (cart == null)
            {
                cart = new Cart();
                _session.Set(SessionKey, cart);
            }

            return cart;
        }

        public void Save(Cart cart)
        {
            _session.Set(SessionKey, cart);
        }

        public void Clear()
        {
            _session.Remove(SessionKey);
        }
    }
}
