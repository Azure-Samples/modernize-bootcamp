using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;

using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    public interface IOrderService
    {
        Order PlaceOrder(Cart cart, string userName);
        Order GetOrder(int id, string userName);
        IEnumerable<Order> GetOrdersForUser(string userName);
        OrderSummary GetSummary(string userName);
    }

    public class OrderService : IOrderService
    {
        // Orders are stored against a store, but the cart has no store concept yet, so every
        // line is booked to the first store until the UI lets the customer choose one.
        private const int DefaultStoreId = 1;

        private readonly IStoreDbContext _context;

        public OrderService(IStoreDbContext context)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
        }

        // The app identifies users by name everywhere; the orders table keys off the user id.
        // Returns 0 (never a real id) when the name is unknown, so callers just find nothing.
        private int ResolveUserId(string userName)
        {
            if (string.IsNullOrWhiteSpace(userName)) return 0;

            return _context.Users
                .Where(u => u.UserName == userName)
                .Select(u => u.Id)
                .FirstOrDefault();
        }

        public Order PlaceOrder(Cart cart, string userName)
        {
            if (cart == null) throw new ArgumentNullException(nameof(cart));
            if (string.IsNullOrWhiteSpace(userName)) throw new ArgumentException("User name is required.", nameof(userName));
            if (cart.IsEmpty) throw new InvalidOperationException("Cannot place an order for an empty cart.");

            var userId = ResolveUserId(userName);
            if (userId == 0) throw new InvalidOperationException("Unknown user '" + userName + "'.");

            var order = new Order
            {
                UserId = userId,
                PlacedUtc = DateTime.UtcNow,
                Total = cart.Total
            };

            foreach (var item in cart.Items)
            {
                order.Lines.Add(new OrderLine
                {
                    StoreId = DefaultStoreId,
                    ProductId = item.ProductId,
                    ProductName = item.Name,
                    UnitPrice = item.UnitPrice,
                    Quantity = item.Quantity
                });
            }

            _context.Orders.Add(order);
            _context.SaveChanges();

            return order;
        }

        public Order GetOrder(int id, string userName)
        {
            var userId = ResolveUserId(userName);

            return _context.Orders
                .Include(o => o.Lines)
                .FirstOrDefault(o => o.Id == id && o.UserId == userId);
        }

        public IEnumerable<Order> GetOrdersForUser(string userName)
        {
            var userId = ResolveUserId(userName);

            return _context.Orders
                .Include(o => o.Lines)
                .Where(o => o.UserId == userId)
                .OrderByDescending(o => o.PlacedUtc)
                .ToList();
        }

        public OrderSummary GetSummary(string userName)
        {
            return _context.GetOrderSummary(ResolveUserId(userName));
        }
    }
}
