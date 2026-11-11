using System;

namespace eShopLite.StoreFx.Models
{
    // Populated by a raw SQL projection, not mapped as an entity.
    public class OrderSummary
    {
        public int OrderCount { get; set; }
        public decimal LifetimeTotal { get; set; }
        public DateTime? FirstOrderUtc { get; set; }
        public DateTime? LastOrderUtc { get; set; }
    }
}
