using System;
using System.Collections.Generic;
using System.Linq;

namespace eShopLite.StoreFx.Models
{
    [Serializable]
    public class CartItem
    {
        public int ProductId { get; set; }
        public string Name { get; set; }
        public string ImageUrl { get; set; }
        public decimal UnitPrice { get; set; }
        public int Quantity { get; set; }

        public decimal LineTotal
        {
            get { return UnitPrice * Quantity; }
        }
    }

    [Serializable]
    public class Cart
    {
        public List<CartItem> Items { get; set; } = new List<CartItem>();

        public int ItemCount
        {
            get { return Items.Sum(i => i.Quantity); }
        }

        public decimal Total
        {
            get { return Items.Sum(i => i.LineTotal); }
        }

        public bool IsEmpty
        {
            get { return Items.Count == 0; }
        }

        public void Add(Product product, int quantity)
        {
            if (product == null) throw new ArgumentNullException(nameof(product));
            if (quantity < 1) quantity = 1;

            var existing = Items.FirstOrDefault(i => i.ProductId == product.Id);
            if (existing != null)
            {
                existing.Quantity += quantity;
                return;
            }

            Items.Add(new CartItem
            {
                ProductId = product.Id,
                Name = product.Name,
                ImageUrl = product.ImageUrl,
                UnitPrice = product.Price,
                Quantity = quantity
            });
        }

        public int GetQuantity(int productId)
        {
            var existing = Items.FirstOrDefault(i => i.ProductId == productId);
            return existing == null ? 0 : existing.Quantity;
        }

        public void SetQuantity(int productId, int quantity)
        {
            if (quantity < 1)
            {
                Remove(productId);
                return;
            }

            var existing = Items.FirstOrDefault(i => i.ProductId == productId);
            if (existing != null)
            {
                existing.Quantity = quantity;
            }
        }

        public void Remove(int productId)
        {
            Items.RemoveAll(i => i.ProductId == productId);
        }

        public void Clear()
        {
            Items.Clear();
        }
    }
}
