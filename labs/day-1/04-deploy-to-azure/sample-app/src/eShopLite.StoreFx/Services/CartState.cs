using System;

using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    /// <summary>
    /// Per-circuit view over the shared <see cref="ICartStore"/>. Components mutate the cart
    /// through this type and subscribe to <see cref="Changed"/> so the badge, the cart page and
    /// the product grid all stay in step without a page reload.
    /// </summary>
    public sealed class CartState
    {
        public const string CookieName = "eshoplite.cart";

        private readonly ICartStore _store;
        private string _key;
        private Cart _cached;

        public CartState(ICartStore store)
        {
            _store = store ?? throw new ArgumentNullException(nameof(store));
        }

        public event Action Changed;

        /// <summary>
        /// Called once per render scope with the cart key resolved from the cookie during the
        /// initial static render. Until then the cart reads as empty rather than throwing.
        /// </summary>
        public void Initialize(string key)
        {
            if (!string.IsNullOrEmpty(key))
            {
                _key = key;
            }
        }

        // Reads now deserialize out of a distributed cache, and a single render touches the cart
        // many times (badge, rows, totals), so the scope holds one copy rather than one per read.
        public Cart Cart
        {
            get
            {
                if (_key == null)
                {
                    return new Cart();
                }

                return _cached ?? (_cached = _store.Get(_key));
            }
        }

        /// <summary>
        /// Drops the cached copy so the next read comes from the store. Pages that display the cart
        /// call this on initialize, which is what picks up a change made in another tab.
        /// </summary>
        public void Refresh()
        {
            _cached = null;
        }

        public void Add(Product product, int quantity)
        {
            Mutate(cart => cart.Add(product, quantity));
        }

        public void SetQuantity(int productId, int quantity)
        {
            Mutate(cart => cart.SetQuantity(productId, quantity));
        }

        public void Remove(int productId)
        {
            Mutate(cart => cart.Remove(productId));
        }

        public void Clear()
        {
            if (_key == null)
            {
                return;
            }

            _store.Remove(_key);
            _cached = null;
            Changed?.Invoke();
        }

        private void Mutate(Action<Cart> mutation)
        {
            if (_key == null)
            {
                return;
            }

            // Read through to the store so a concurrent change from another tab is not clobbered.
            var cart = _store.Get(_key);
            mutation(cart);
            _store.Save(_key, cart);

            _cached = cart;
            Changed?.Invoke();
        }
    }
}
