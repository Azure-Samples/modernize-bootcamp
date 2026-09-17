using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace eShopLite.StoreFx.Models
{
    // Table name pinned: EF Core would otherwise derive it from the DbSet name ("Stores").
    [Table("Store")]
    public class StoreInfo
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }
        [JsonPropertyName("name")]
        public string Name { get; set; }
        [JsonPropertyName("city")]
        public string City { get; set; }
        [JsonPropertyName("state")]
        public string State { get; set; }
        [JsonPropertyName("hours")]
        public string Hours { get; set; }
    }
}
