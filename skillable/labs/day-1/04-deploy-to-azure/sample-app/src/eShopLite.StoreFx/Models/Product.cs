using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace eShopLite.StoreFx.Models
{
    // Table name pinned: EF Core would otherwise derive it from the DbSet name ("Products").
    [Table("Product")]
    public class Product
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }

        [JsonPropertyName("name")]
        public string Name { get; set; }

        [JsonPropertyName("description")]
        public string Description { get; set; }

        [JsonPropertyName("price")]
        public decimal Price { get; set; }

        [JsonPropertyName("imageUrl")]
        public string ImageUrl { get; set; }
    }
}
