using System;
using System.Data.Entity;
using System.IO;

using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Models;
using eShopLite.StoreFx.Services;

using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);

// Replaces <connectionStrings configSource="connectionStrings.config" /> from Web.config. The value
// is deliberately absent from appsettings.json so the password can never be committed.
var connectionString = builder.Configuration.GetConnectionString("StoreDbContext");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Connection string 'StoreDbContext' is not configured. Supply it with " +
        "`dotnet user-secrets set \"ConnectionStrings:StoreDbContext\" \"<connection string>\"` " +
        "or the ConnectionStrings__StoreDbContext environment variable. " +
        "See docs/remote-sql-setup.md.");
}

// The SQL schema scripts are the source of truth; EF must never alter the database.
Database.SetInitializer<StoreDbContext>(null);

builder.Services.AddControllersWithViews();

// Replaces <authentication mode="Forms"><forms loginUrl="~/Account/Login" timeout="30"
// name=".ESHOPLITEAUTH" protection="All" slidingExpiration="true" requireSSL="false" />.
// protection="All" and <machineKey> need no port: Data Protection encrypts and signs the cookie.
// The Web.config declared no <authorization> element, so no fallback policy is registered and
// anonymous routes stay anonymous.
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = ".ESHOPLITEAUTH";
        options.LoginPath = "/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromMinutes(30);
        options.SlidingExpiration = true;
    });

builder.Services.AddHttpContextAccessor();

// Matches the <sessionState mode="InProc" timeout="30" /> the Web.config declared.
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

// TODO: adapter-cleanup — replace HttpContext.Current/Session["key"] usage with IHttpContextAccessor and ISession.
// The wrapped session serializes each value, so every key's type must be registered up front;
// an unregistered key throws on read. Cart is the only object this app puts in session.
builder.Services.AddSystemWebAdapters()
    .AddJsonSessionSerializer(options => options.RegisterKey<Cart>(SessionCartService.SessionKey))
    .AddWrappedAspNetCoreSession();

RegisterApplicationServices(builder.Services, connectionString);

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

// Replaces the single global HandleErrorAttribute that FilterConfig registered.
app.UseExceptionHandler("/Home/Error");

// This app predates wwwroot: assets live in Content/, Scripts/ and Images/ at the project root.
// Each folder is mounted explicitly rather than pointing the web root at the project directory,
// which would serve Web.config and connectionStrings.config over HTTP.
UseStaticAssetFolder(app, "Content");
UseStaticAssetFolder(app, "Scripts");
UseStaticAssetFolder(app, "Images");

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.UseSession();
app.UseSystemWebAdapters();

app.MapGet("/health", () => "Healthy");
app.MapGet("/healthz", () => "Healthy");

// System.Web adapter session is opt-in per endpoint: without this the adapters' session middleware
// never runs, HttpContext.Current.Session stays null, and every ISessionStore read silently
// returns null. Web.config's <sessionState> applied to every request, so every endpoint opts in.
app.MapDefaultControllerRoute()
    .RequireSystemWebAdapterSession();

app.Run();

// Ported from the Autofac ContainerBuilder that Global.asax.cs Application_Start built.
static void RegisterApplicationServices(IServiceCollection services, string connectionString)
{
    // One context per request, so every service in a request shares a single unit of work.
    // EF6 has no AddDbContext equivalent, so the connection string is passed to the constructor.
    services.AddScoped<IStoreDbContext>(_ => new StoreDbContext(connectionString));

    // Autofac's default lifetime is InstancePerDependency, so these stay transient.
    services.AddTransient<ISessionStore, HttpContextSessionStore>();
    services.AddTransient<IStoreService, StoreService>();
    services.AddTransient<IAuthService, AuthService>();
    services.AddTransient<ICartService, SessionCartService>();
    services.AddTransient<IOrderService, OrderService>();
}

static void UseStaticAssetFolder(WebApplication app, string folderName)
{
    var path = Path.Combine(app.Environment.ContentRootPath, folderName);
    if (!Directory.Exists(path))
    {
        return;
    }

    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(path),
        RequestPath = "/" + folderName
    });
}
