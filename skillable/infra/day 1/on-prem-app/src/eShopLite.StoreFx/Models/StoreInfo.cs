using System.ComponentModel.DataAnnotations.Schema;

using Newtonsoft.Json;

namespace eShopLite.StoreFx.Models
{
    // Table name pinned: EF Core would otherwise derive it from the DbSet name ("Stores").
    [Table("Store")]
    public class StoreInfo
    {
        [JsonProperty("id")]
        public int Id { get; set; }
        [JsonProperty("name")]
        public string Name { get; set; }
        [JsonProperty("city")]
        public string City { get; set; }
        [JsonProperty("state")]
        public string State { get; set; }
        [JsonProperty("hours")]
        public string Hours { get; set; }
    }
}
