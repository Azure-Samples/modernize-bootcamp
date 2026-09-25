using System;
using System.Text.Json;

using eShopLite.StoreFx.Models;

using Microsoft.Extensions.Caching.Distributed;

namespace eShopLite.StoreFx.Services
{
    /// <summary>
    /// Cart storage backed by <see cref="IDistributedCache"/>. Registered against Redis when a
    /// connection string is supplied and an in-process cache otherwise, so the same code path runs
    /// locally and on Azure and scaling out is a configuration change rather than a rewrite.
    /// </summary>
    public sealed class DistributedCartStore : ICartStore
    {
        // Matches the 30 minute idle timeout of the session this ultimately replaced.
        private static readonly DistributedCacheEntryOptions Expiry = new DistributedCacheEntryOptions
        {
            SlidingExpiration = TimeSpan.FromMinutes(30)
        };

        private static readonly JsonSerializerOptions SerializerOptions = new JsonSerializerOptions
        {
            // Cart exposes computed properties (Total, ItemCount, IsEmpty) with no setter; only
            // Items round-trips, and everything else is recalculated on read.
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        private readonly IDistributedCache _cache;

        public DistributedCartStore(IDistributedCache cache)
        {
            _cache = cache ?? throw new ArgumentNullException(nameof(cache));
        }

        public Cart Get(string key)
        {
            var payload = _cache.GetString(CacheKey(key));
            if (string.IsNullOrEmpty(payload))
            {
                return new Cart();
            }

            try
            {
                return JsonSerializer.Deserialize<Cart>(payload, SerializerOptions) ?? new Cart();
            }
            catch (JsonException)
            {
                // A cart shape change must not lock a customer out of the store.
                return new Cart();
            }
        }

        public void Save(string key, Cart cart)
        {
            _cache.SetString(CacheKey(key), JsonSerializer.Serialize(cart ?? new Cart(), SerializerOptions), Expiry);
        }

        public void Remove(string key)
        {
            _cache.Remove(CacheKey(key));
        }

        private static string CacheKey(string key)
        {
            return "cart:" + key;
        }
    }
}
