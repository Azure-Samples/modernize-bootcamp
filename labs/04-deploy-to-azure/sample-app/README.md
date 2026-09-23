# eShopLite.StoreFx

A **Blazor** storefront on **.NET 10**, backed by Entity Framework 6 and SQL Server.

Upgraded from ASP.NET MVC 5 on .NET Framework 4.8, then converted from ASP.NET Core MVC
(controllers + Razor views) to Blazor components. See `.github/upgrades/` for the assessment,
plan, and a per-task record of what changed.

## Architecture

- **Blazor Web App** with the **Interactive Server** render mode applied globally. The data lives in
  SQL Server behind EF 6, so there is no API layer a WebAssembly client could call, and EF 6 has no
  browser-compatible build.
- Pages live in `src/eShopLite.StoreFx/Components/Pages`, shared UI in `Components/Shared`, and the
  shell in `Components/Layout`.
- Sign-in and sign-out post to minimal API endpoints under `/auth/`, because issuing or clearing the
  authentication cookie needs an `HttpContext` and a Blazor circuit does not have one.
- The cart is held server-side and keyed by a browser cookie, replacing the `System.Web` session the
  MVC app used.

## Run it

1. Open [src/eShopLite.StoreFx/appsettings.json](src/eShopLite.StoreFx/appsettings.json) and replace
   `REPLACE_ME` with the database password. Nothing else needs changing.

2. ```
   dotnet run --project src/eShopLite.StoreFx
   ```

Then browse to the URL it prints.

Sign in as `alice` or `bob` — both are customers with existing order history. Credentials are in
[Copilot Essentials](../../../docs/copilot-essentials.md#-demo-accounts).

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- Network access to the SQL Server named in the connection string

## Notes

- Keep the password out of source control on any real deployment — override it with
  `dotnet user-secrets set "ConnectionStrings:StoreDbContext" "<connection string>"` or the
  `ConnectionStrings__StoreDbContext` environment variable. Both take precedence over
  `appsettings.json`.
- Passwords are stored as salted SHA-1 (legacy) and verified alongside PBKDF2 for any newly set
  password. This is a sample; see `Services/AuthService.cs` before reusing that code.
- Carts are kept in memory, so they are lost when the process restarts — the same behaviour as the
  in-proc session this replaced. Swap `InMemoryCartStore` for a distributed cache to survive
  restarts or to run more than one instance.
