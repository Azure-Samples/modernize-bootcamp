using System;

namespace eShopLite.StoreFx.Models
{
    /// <summary>
    /// The catalogue stores a bare file name ("product1.png"). The MVC views resolved it with
    /// <c>~/images/</c>; wwwroot serves the same folder now, so the mapping lives here instead of
    /// being repeated in every component.
    /// </summary>
    public static class ProductImage
    {
        private const string Folder = "/images/";
        private const string Placeholder = "/images/product1.png";

        public static string UrlFor(string imageUrl)
        {
            if (string.IsNullOrWhiteSpace(imageUrl))
            {
                return Placeholder;
            }

            var name = imageUrl.Trim();

            if (name.StartsWith("/", StringComparison.Ordinal) ||
                name.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                name.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                return name;
            }

            return Folder + name.TrimStart('~', '/');
        }
    }
}
