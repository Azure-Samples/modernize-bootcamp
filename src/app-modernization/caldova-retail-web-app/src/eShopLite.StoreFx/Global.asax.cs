using System;
using System.Data.Entity;
using System.Linq;
using System.Security.Principal;
using System.Web.Mvc;
using System.Web.Routing;
using System.Web.Security;

using Autofac;
using Autofac.Integration.Mvc;

using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Services;

namespace eShopLite.StoreFx
{
    public class MvcApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            // The SQL schema scripts are the source of truth; EF must never alter the database.
            Database.SetInitializer<StoreDbContext>(null);

            var builder = new ContainerBuilder();

            // Register your MVC controllers
            builder.RegisterControllers(typeof(MvcApplication).Assembly);

            // Register other dependencies
            // One context per request, so every service in a request shares a single unit of work.
            builder.RegisterType<StoreDbContext>().As<IStoreDbContext>().InstancePerRequest();
            builder.RegisterType<HttpContextSessionStore>().As<ISessionStore>();
            builder.RegisterType<StoreService>().As<IStoreService>();
            builder.RegisterType<AuthService>().As<IAuthService>();
            builder.RegisterType<SessionCartService>().As<ICartService>();
            builder.RegisterType<OrderService>().As<IOrderService>();

            var container = builder.Build();
            DependencyResolver.SetResolver(new AutofacDependencyResolver(container));

            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
        }

        // Roles are packed into the auth ticket's UserData by AccountController; unpack them here so
        // [Authorize(Roles = "...")] and User.IsInRole work on every request.
        protected void Application_PostAuthenticateRequest()
        {
            var identity = Context.User?.Identity;
            if (identity == null || !identity.IsAuthenticated)
            {
                return;
            }

            var cookie = Request.Cookies[FormsAuthentication.FormsCookieName];
            if (cookie == null || string.IsNullOrEmpty(cookie.Value))
            {
                return;
            }

            FormsAuthenticationTicket ticket;
            try
            {
                ticket = FormsAuthentication.Decrypt(cookie.Value);
            }
            catch (Exception)
            {
                // A tampered or undecryptable cookie must not authenticate the request.
                FormsAuthentication.SignOut();
                Context.User = new GenericPrincipal(new GenericIdentity(string.Empty), new string[0]);
                return;
            }

            if (ticket == null || ticket.Expired)
            {
                return;
            }

            var roles = (ticket.UserData ?? string.Empty)
                .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(role => role.Trim())
                .Where(role => role.Length > 0)
                .ToArray();

            Context.User = new GenericPrincipal(new FormsIdentity(ticket), roles);
        }
    }
}
