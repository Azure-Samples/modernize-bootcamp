using eShopLite.StoreFx.Services;

using Microsoft.AspNetCore.Mvc;

namespace eShopLite.StoreFx.ViewComponents
{
    // Was HomeController.ProductDetails, a [ChildActionOnly] + [OutputCache(Duration = 300)] action.
    // Child actions do not exist in ASP.NET Core; the 300s cache now lives in the <cache> tag helper
    // that wraps the invocation in Views/Home/Product.cshtml.
    public class ProductDetailsViewComponent : ViewComponent
    {
        private readonly IStoreService _service;

        public ProductDetailsViewComponent(IStoreService service)
        {
            _service = service ?? throw new System.ArgumentNullException(nameof(service));
        }

        public IViewComponentResult Invoke(int id)
        {
            var product = _service.GetProduct(id);

            if (product == null)
            {
                return Content(string.Empty);
            }

            return View(product);
        }
    }
}
