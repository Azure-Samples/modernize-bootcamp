using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;

using Azure.Identity;
using Azure.Monitor.OpenTelemetry.AspNetCore;

using eShopLite.StoreFx.Components;
using eShopLite.StoreFx.Data;
using eShopLite.StoreFx.Services;

using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var builder = WebApplication.CreateBuilder(args);

// The value is deliberately absent from appsettings.json so the password can never be committed.
var connectionString = builder.Configuration.GetConnectionString("StoreDbContext");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Connection string 'StoreDbContext' is not configured. Supply it with " +
        "`dotnet user-secrets set \"ConnectionStrings:StoreDbContext\" \"<connection string>\"` " +
        "or the ConnectionStrings__StoreDbContext environment variable.");
}

// The SQL schema scripts are the source of truth; EF must never alter the database.
Database.SetInitializer<StoreDbContext>(null);

// TLS terminates at the Azure ingress, so without this the app sees plain HTTP: Request.IsHttps
// would be false, the cart cookie would ship without the Secure flag and an HTTPS redirect would
// loop forever. Azure overwrites these headers at the edge, so no proxy allow-list is needed.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

var dataProtectionWarning = ConfigureDataProtection(builder);

ConfigureTelemetry(builder);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

ConfigureCircuitTransport(builder);

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = ".ESHOPLITEAUTH";
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = builder.Environment.IsDevelopment()
            ? CookieSecurePolicy.SameAsRequest
            : CookieSecurePolicy.Always;
        options.LoginPath = "/account/login";
        options.ExpireTimeSpan = TimeSpan.FromMinutes(30);
        options.SlidingExpiration = true;
    });

builder.Services.AddAuthorization();
builder.Services.AddCascadingAuthenticationState();

builder.Services.AddSingleton(new StoreDatabaseHealthCheck(connectionString));
builder.Services.AddHealthChecks()
    .AddCheck<StoreDatabaseHealthCheck>(
        "catalogue-database",
        failureStatus: HealthStatus.Unhealthy,
        tags: new[] { "ready" },
        timeout: TimeSpan.FromSeconds(5));

RegisterApplicationServices(builder.Services, builder.Configuration, connectionString);

var app = builder.Build();

if (dataProtectionWarning != null)
{
    app.Logger.LogWarning(dataProtectionWarning);
}

// Must run before anything reads the scheme, the client IP or a cookie policy.
app.UseForwardedHeaders();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseExceptionHandler("/error", createScopeForErrors: true);

// Without this an unmatched URL returns a bare 404 with no body - a blank page in the browser.
app.UseStatusCodePagesWithReExecute("/not-found");

app.UseAuthentication();
app.UseAuthorization();

app.UseAntiforgery();

// Serves wwwroot *and* the framework's own assets (blazor.web.js) from the build-time endpoint
// manifest. UseStaticFiles would only find package assets in Development.
app.MapStaticAssets();

// Liveness answers "is the process up"; readiness additionally proves SQL is reachable, so a
// broken instance is taken out of rotation instead of serving errors.
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = check => check.Tags.Contains("ready") });

// Retained so existing probes keep working.
app.MapHealthChecks("/health", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/healthz", new HealthCheckOptions { Predicate = _ => false });

MapAccountEndpoints(app);

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();

static void RegisterApplicationServices(
    IServiceCollection services,
    IConfiguration configuration,
    string connectionString)
{
    // One short-lived EF6 context per unit of work. A scoped context would live for the whole
    // Blazor circuit and keep serving its first-level cache long after the page that opened it.
    services.AddSingleton<IStoreDbContextFactory>(_ => new StoreDbContextFactory(connectionString));

    services.AddTransient<IStoreService, StoreService>();
    services.AddTransient<IAuthService, AuthService>();
    services.AddTransient<IOrderService, OrderService>();

    // Redis when configured, in-process otherwise. The in-process cache is per-instance, so a
    // multi-replica deployment needs the connection string or customers lose carts between hits.
    var redisConnectionString = configuration.GetConnectionString("Redis");
    if (!string.IsNullOrWhiteSpace(redisConnectionString))
    {
        services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = redisConnectionString;
            options.InstanceName = "eshoplite:";
        });
    }
    else
    {
        services.AddDistributedMemoryCache();
    }

    services.AddSingleton<ICartStore, DistributedCartStore>();

    // Scoped == per circuit for interactive components, per request while prerendering.
    services.AddScoped<CartState>();
    services.AddScoped<ToastService>();
}

// Keys default to a folder inside the container, so every restart invalidates every auth cookie
// and antiforgery token, and two replicas cannot read each other's. Persisting them to Blob
// Storage and wrapping them with a Key Vault key is what makes restarts and scale-out survivable.
// Returns a warning to log once the host can log, or null when keys are persisted.
static string ConfigureDataProtection(WebApplicationBuilder builder)
{
    var keys = builder.Services.AddDataProtection()
        // Pins the key ring's isolation identifier so it survives a rename of the content root.
        .SetApplicationName("eShopLite.StoreFx");

    var blobUri = builder.Configuration["DataProtection:BlobUri"];
    var keyVaultKeyId = builder.Configuration["DataProtection:KeyVaultKeyId"];

    if (string.IsNullOrWhiteSpace(blobUri))
    {
        return builder.Environment.IsDevelopment()
            ? null
            : "Data protection keys are not persisted. Set DataProtection:BlobUri, or every restart " +
              "will sign out all users and invalidate in-flight login forms.";
    }

    var credential = new DefaultAzureCredential();
    keys.PersistKeysToAzureBlobStorage(new Uri(blobUri), credential);

    if (!string.IsNullOrWhiteSpace(keyVaultKeyId))
    {
        keys.ProtectKeysWithAzureKeyVault(new Uri(keyVaultKeyId), credential);
    }

    return null;
}

// The app ships no telemetry today, so a production incident leaves nothing to look at. Traces,
// metrics and logs go to Application Insights when a connection string is present, and the whole
// exporter stays out of the pipeline when it is not.
static void ConfigureTelemetry(WebApplicationBuilder builder)
{
    var connectionString = builder.Configuration["ApplicationInsights:ConnectionString"]
        ?? builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        return;
    }

    builder.Services.AddOpenTelemetry().UseAzureMonitor(options =>
    {
        options.ConnectionString = connectionString;
    });
}

// A Blazor Server circuit is a stateful SignalR connection, so a second replica needs either
// sticky sessions or an external backplane. Azure SignalR is the backplane and also moves the
// long-lived websockets off the app instances, which is what lets them restart cleanly.
static void ConfigureCircuitTransport(WebApplicationBuilder builder)
{
    var connectionString = builder.Configuration.GetConnectionString("AzureSignalR");

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        return;
    }

    builder.Services.AddSignalR().AddAzureSignalR(options =>
    {
        options.ConnectionString = connectionString;
    });
}

// Sign-in and sign-out have to run on a real HTTP request: a Blazor circuit has no HttpContext,
// so it can neither issue nor clear the authentication cookie. The paths deliberately differ from
// the /account/login page route - a routable component already owns POST on its own path.
static void MapAccountEndpoints(WebApplication app)
{
    app.MapPost("/auth/login", async (HttpContext http, IAuthService authService, IAntiforgery antiforgery) =>
    {
        if (!await IsRequestValidAsync(http, antiforgery))
        {
            return Results.Redirect("/account/login?error=expired");
        }

        var form = await http.Request.ReadFormAsync();
        var userName = form["userName"].ToString();
        var password = form["password"].ToString();
        var rememberMe = form["rememberMe"].ToString().StartsWith("t", StringComparison.OrdinalIgnoreCase);
        var returnUrl = form["returnUrl"].ToString();

        var user = await authService.ValidateUserAsync(userName, password);
        if (user == null)
        {
            var query = "?error=invalid";
            if (IsLocalUrl(returnUrl))
            {
                query += "&returnUrl=" + Uri.EscapeDataString(returnUrl);
            }

            return Results.Redirect("/account/login" + query);
        }

        // Replaces the FormsAuthenticationTicket that carried user.Roles in UserData: the roles are
        // now individual claims, and the default NameClaimType/RoleClaimType keep User.Identity.Name,
        // User.IsInRole(...) and [Authorize(Roles = "...")] working unchanged.
        var claims = new List<Claim> { new Claim(ClaimTypes.Name, user.UserName) };

        // The legacy Roles column is a single comma-separated string.
        if (!string.IsNullOrWhiteSpace(user.Roles))
        {
            foreach (var role in user.Roles.Split(
                ',',
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }
        }

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

        await http.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties { IsPersistent = rememberMe });

        return Results.Redirect(IsLocalUrl(returnUrl) ? returnUrl : "/");
    });

    app.MapPost("/auth/logout", async (HttpContext http, IAntiforgery antiforgery) =>
    {
        if (await IsRequestValidAsync(http, antiforgery))
        {
            await http.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        }

        return Results.Redirect("/");
    });
}

static async Task<bool> IsRequestValidAsync(HttpContext http, IAntiforgery antiforgery)
{
    try
    {
        await antiforgery.ValidateRequestAsync(http);
        return true;
    }
    catch (AntiforgeryValidationException)
    {
        return false;
    }
}

// Blocks the open redirect an attacker-supplied returnUrl would otherwise allow: protocol-relative
// ("//evil.com") and backslash forms are rejected along with absolute URLs.
static bool IsLocalUrl(string url)
{
    if (string.IsNullOrEmpty(url) || url[0] != '/')
    {
        return false;
    }

    return url.Length == 1 || (url[1] != '/' && url[1] != '\\');
}
