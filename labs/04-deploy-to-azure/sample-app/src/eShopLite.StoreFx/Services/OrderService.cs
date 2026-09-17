using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;

using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Models;

namespace eShopLite.StoreFx.Services
{
    public interface IOrderService
    {
        Task<Order> PlaceOrderAsync(Cart cart, string userName);
        Task<Order> GetOrderAsync(int id, string userName);
        Task<IReadOnlyList<Order>> GetOrdersForUserAsync(string userName);
        Task<OrderSummary> GetSummaryAsync(string userName);
    }

    public class OrderService : IOrderService
    {
        // Orders are stored against a store, but the cart has no store concept yet, so every
        // line is booked to the first store until the UI lets the customer choose one.
        private const int DefaultStoreId = 1;

        private readonly IStoreDbContextFactory _contextFactory;

        public OrderService(IStoreDbContextFactory contextFactory)
        {
            _contextFactory = contextFactory ?? throw new ArgumentNullException(nameof(contextFactory));
        }

        // The app identifies users by name everywhere; the orders table keys off the user id.
        // Returns 0 (never a real id) when the name is unknown, so callers just find nothing.
        private static Task<int> ResolveUserIdAsync(IStoreDbContext context, string userName)
        {
            if (string.IsNullOrWhiteSpace(userName)) return Task.FromResult(0);

            return context.Users
                .Where(u => u.UserName == userName)
                .Select(u => u.Id)
                .FirstOrDefaultAsync();
        }

        public async Task<Order> PlaceOrderAsync(Cart cart, string userName)
        {
            if (cart == null) throw new ArgumentNullException(nameof(cart));
            if (string.IsNullOrWhiteSpace(userName)) throw new ArgumentException("User name is required.", nameof(userName));
            if (cart.IsEmpty) throw new InvalidOperationException("Cannot place an order for an empty cart.");

            using (var context = _contextFactory.Create())
            {
                var userId = await ResolveUserIdAsync(context, userName);
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

                context.Orders.Add(order);
                await context.SaveChangesAsync();

                return order;
            }
        }

        public async Task<Order> GetOrderAsync(int id, string userName)
        {
            using (var context = _contextFactory.Create())
            {
                var userId = await ResolveUserIdAsync(context, userName);

                return await context.Orders
                    .Include(o => o.Lines)
                    .FirstOrDefaultAsync(o => o.Id == id && o.UserId == userId);
            }
        }

        public async Task<IReadOnlyList<Order>> GetOrdersForUserAsync(string userName)
        {
            using (var context = _contextFactory.Create())
            {
                var userId = await ResolveUserIdAsync(context, userName);

                return await context.Orders
                    .Include(o => o.Lines)
                    .Where(o => o.UserId == userId)
                    .OrderByDescending(o => o.PlacedUtc)
                    .ToListAsync();
            }
        }

        public async Task<OrderSummary> GetSummaryAsync(string userName)
        {
            using (var context = _contextFactory.Create())
            {
                var userId = await ResolveUserIdAsync(context, userName);

                return await context.GetOrderSummaryAsync(userId);
            }
        }
    }
}
