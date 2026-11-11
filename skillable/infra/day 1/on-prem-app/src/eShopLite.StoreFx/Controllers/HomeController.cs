using System.Web.Mvc;

using eShopLite.StoreFx.Services;

namespace eShopLite.StoreFx.Controllers
{
    public class HomeController : Controller
    {
        private readonly IStoreService _service;

        public HomeController(IStoreService service)
        {
            _service = service ?? throw new System.ArgumentNullException(nameof(service));
        }

        public ActionResult Index()
        {
            return View();
        }

        public ActionResult Products(string q)
        {
            ViewBag.Message = "This component demonstrates showing products data";
            ViewBag.SearchTerm = q;

            var products = _service.SearchProducts(q);

            return View(products);
        }

        public ActionResult Product(int id)
        {
            var product = _service.GetProduct(id);

            if (product == null)
            {
                return HttpNotFound();
            }

            return View(product);
        }

        // Only the impersonal part of the page is cached. The surrounding view keeps the
        // greeting, cart badge and antiforgery token out of the cache entry.
        [ChildActionOnly]
        [OutputCache(Duration = 300)]
        public ActionResult ProductDetails(int id)
        {
            var product = _service.GetProduct(id);

            if (product == null)
            {
                return new EmptyResult();
            }

            return PartialView("_ProductDetails", product);
        }

        public ActionResult Stores()
        {
            ViewBag.Message = "This component demonstrates showing stores data";

            var stores = _service.GetStores();

            return View(stores);
        }
    }
}