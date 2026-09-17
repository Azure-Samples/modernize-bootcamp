using eShopLite.StoreFx.Services;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eShopLite.StoreFx.Controllers
{
    [Authorize]
    public class OrderController : Controller
    {
        private readonly IOrderService _orderService;

        public OrderController(IOrderService orderService)
        {
            _orderService = orderService ?? throw new System.ArgumentNullException(nameof(orderService));
        }

        public IActionResult Index()
        {
            // Always the signed-in user, never a route value.
            var userName = User.Identity.Name;

            ViewBag.Summary = _orderService.GetSummary(userName);

            var orders = _orderService.GetOrdersForUser(userName);

            return View(orders);
        }
    }
}
