using eShopLite.StoreFx.Services;

using Microsoft.AspNetCore.Mvc;

namespace eShopLite.StoreFx.Controllers
{
    public class HomeController : Controller
    {
        private readonly IStoreService _service;

        public HomeController(IStoreService service)
        {
            _service = service ?? throw new System.ArgumentNullException(nameof(service));
        }

        public IActionResult Index()
        {
            return View();
        }

        // Target of app.UseExceptionHandler("/Home/Error") in Program.cs.
        public IActionResult Error()
        {
            return View("Error");
        }

        public IActionResult Products(string q)
        {
            ViewBag.Message = "This component demonstrates showing products data";
            ViewBag.SearchTerm = q;

            var products = _service.SearchProducts(q);

            return View(products);
        }

        public IActionResult Product(int id)
        {
            var product = _service.GetProduct(id);

            if (product == null)
            {
                return NotFound();
            }

            return View(product);
        }

        // ProductDetails moved to ViewComponents/ProductDetailsViewComponent.cs — child actions and
        // [OutputCache] do not exist in ASP.NET Core. Only the impersonal part of the page is cached;
        // the surrounding view keeps the greeting, cart badge and antiforgery token out of the entry.

        public IActionResult Stores()
        {
            ViewBag.Message = "This component demonstrates showing stores data";

            var stores = _service.GetStores();

            return View(stores);
        }
    }
}