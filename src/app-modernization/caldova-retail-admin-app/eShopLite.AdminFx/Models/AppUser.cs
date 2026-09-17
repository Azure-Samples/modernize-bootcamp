using Newtonsoft.Json;

namespace eShopLite.AdminFx.Models
{
    public class AppUser
    {
        [JsonProperty("username")]
        public string Username { get; set; }

        [JsonProperty("passwordHash")]
        public string PasswordHash { get; set; }

        [JsonProperty("role")]
        public string Role { get; set; }

        [JsonProperty("displayName")]
        public string DisplayName { get; set; }
    }
}
