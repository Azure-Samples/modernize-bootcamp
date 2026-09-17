namespace eShopLite.AdminFx.Models
{
    public class AdminSettings
    {
        public string ProductsApiBaseUrl { get; set; }

        public int ProductsApiTimeoutSeconds { get; set; }

        public string OrdersFilePath { get; set; }

        public string UsersFilePath { get; set; }

        public string ProductsApiKey { get; set; }
    }
}
