using System;
using System.Web;
using System.Web.Mvc;
using System.Web.Security;

using eShopLite.StoreFx.Models;
using eShopLite.StoreFx.Services;

namespace eShopLite.StoreFx.Controllers
{
    [Authorize]
    public class AccountController : Controller
    {
        private readonly IAuthService _authService;

        public AccountController(IAuthService authService)
        {
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
        }

        [AllowAnonymous]
        public ActionResult Login(string returnUrl)
        {
            ViewBag.ReturnUrl = returnUrl;

            return View(new LoginViewModel());
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public ActionResult Login(LoginViewModel model, string returnUrl)
        {
            ViewBag.ReturnUrl = returnUrl;

            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var user = _authService.ValidateUser(model.UserName, model.Password);
            if (user == null)
            {
                ModelState.AddModelError(string.Empty, "Invalid user name or password.");

                return View(model);
            }

            IssueAuthCookie(user, model.RememberMe);

            if (Url.IsLocalUrl(returnUrl))
            {
                return Redirect(returnUrl);
            }

            return RedirectToAction("Index", "Home");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Logout()
        {
            FormsAuthentication.SignOut();
            Session.Abandon();

            return RedirectToAction("Index", "Home");
        }

        // Roles are packed into the ticket's UserData and unpacked in Global.asax
        // (Application_PostAuthenticateRequest) - the classic Forms auth pattern.
        private void IssueAuthCookie(User user, bool persistent)
        {
            var ticket = new FormsAuthenticationTicket(
                version: 1,
                name: user.UserName,
                issueDate: DateTime.Now,
                expiration: DateTime.Now.AddMinutes(FormsAuthentication.Timeout.TotalMinutes),
                isPersistent: persistent,
                userData: user.Roles ?? string.Empty,
                cookiePath: FormsAuthentication.FormsCookiePath);

            var cookie = new HttpCookie(FormsAuthentication.FormsCookieName, FormsAuthentication.Encrypt(ticket))
            {
                HttpOnly = true,
                Secure = FormsAuthentication.RequireSSL,
                Path = FormsAuthentication.FormsCookiePath
            };

            if (persistent)
            {
                cookie.Expires = ticket.Expiration;
            }

            Response.Cookies.Add(cookie);
        }
    }
}
