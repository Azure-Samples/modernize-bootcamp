using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eShopLite.StoreFx.Models
{
    // Table name pinned: EF Core would otherwise derive it from the DbSet name ("Orders").
    [Table("Order")]
    public class Order
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public DateTime PlacedUtc { get; set; }

        [Column(TypeName = "money")]
        public decimal Total { get; set; }

        public virtual ICollection<OrderLine> Lines { get; set; } = new List<OrderLine>();
    }

    [Table("OrderLine")]
    public class OrderLine
    {
        public int Id { get; set; }

        public int OrderId { get; set; }

        public int StoreId { get; set; }

        public int ProductId { get; set; }

        [Required]
        [StringLength(200)]
        public string ProductName { get; set; }

        [Column(TypeName = "money")]
        public decimal UnitPrice { get; set; }

        public int Quantity { get; set; }

        public virtual Order Order { get; set; }
    }
}
