using System;
using System.Collections.Generic;
using System.Linq;

using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    public interface IStoreService
    {
        IEnumerable<Product> GetProducts();
        IEnumerable<Product> SearchProducts(string searchTerm);
        Product GetProduct(int id);
        IEnumerable<StoreInfo> GetStores();
    }

    public class StoreService : IStoreService
    {
        // The catalogue holds ~50k rows but only product1..product9.png ship with the app,
        // so anything past the first nine renders a broken image.
        private const int MaxProducts = 9;
        private const int MaxStores = 15;

        private readonly IStoreDbContext _context;

        public StoreService(IStoreDbContext context)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
        }

        public IEnumerable<Product> GetProducts()
        {
            return _context.Products
                .OrderBy(p => p.Id)
                .Take(MaxProducts)
                .ToList();
        }

        public IEnumerable<Product> SearchProducts(string searchTerm)
        {
            if (string.IsNullOrWhiteSpace(searchTerm))
            {
                return GetProducts();
            }

            var term = searchTerm.Trim();

            return _context.Products
                .Where(p => p.Name.Contains(term) || p.Description.Contains(term))
                .OrderBy(p => p.Name)
                .Take(MaxProducts)
                .ToList();
        }

        public Product GetProduct(int id)
        {
            return _context.Products.FirstOrDefault(p => p.Id == id);
        }

        public IEnumerable<StoreInfo> GetStores()
        {
            return _context.Stores
                .OrderBy(s => s.Id)
                .Take(MaxStores)
                .ToList();
        }
    }
}