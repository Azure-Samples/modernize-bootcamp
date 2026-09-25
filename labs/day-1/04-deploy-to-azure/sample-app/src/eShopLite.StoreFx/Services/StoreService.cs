using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;

using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    public interface IStoreService
    {
        Task<IReadOnlyList<Product>> GetProductsAsync();
        Task<IReadOnlyList<Product>> SearchProductsAsync(string searchTerm);
        Task<Product> GetProductAsync(int id);
        Task<IReadOnlyList<StoreInfo>> GetStoresAsync();
    }

    public class StoreService : IStoreService
    {
        // The catalogue holds ~50k rows but only product1..product9.png ship with the app,
        // so anything past the first nine renders a broken image.
        private const int MaxProducts = 9;
        private const int MaxStores = 15;

        private readonly IStoreDbContextFactory _contextFactory;

        public StoreService(IStoreDbContextFactory contextFactory)
        {
            _contextFactory = contextFactory ?? throw new ArgumentNullException(nameof(contextFactory));
        }

        public async Task<IReadOnlyList<Product>> GetProductsAsync()
        {
            using (var context = _contextFactory.Create())
            {
                return await context.Products
                    .OrderBy(p => p.Id)
                    .Take(MaxProducts)
                    .ToListAsync();
            }
        }

        public async Task<IReadOnlyList<Product>> SearchProductsAsync(string searchTerm)
        {
            if (string.IsNullOrWhiteSpace(searchTerm))
            {
                return await GetProductsAsync();
            }

            var term = searchTerm.Trim();

            using (var context = _contextFactory.Create())
            {
                return await context.Products
                    .Where(p => p.Name.Contains(term) || p.Description.Contains(term))
                    .OrderBy(p => p.Name)
                    .Take(MaxProducts)
                    .ToListAsync();
            }
        }

        public async Task<Product> GetProductAsync(int id)
        {
            using (var context = _contextFactory.Create())
            {
                return await context.Products.FirstOrDefaultAsync(p => p.Id == id);
            }
        }

        public async Task<IReadOnlyList<StoreInfo>> GetStoresAsync()
        {
            using (var context = _contextFactory.Create())
            {
                return await context.Stores
                    .OrderBy(s => s.Id)
                    .Take(MaxStores)
                    .ToListAsync();
            }
        }
    }
}
