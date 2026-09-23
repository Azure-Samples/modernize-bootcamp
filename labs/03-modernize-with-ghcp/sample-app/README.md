# eShopLite.StoreFx

An ASP.NET Core MVC storefront on **.NET 10**, backed by Entity Framework 6 and SQL Server.

Upgraded from ASP.NET MVC 5 on .NET Framework 4.8. See `.github/upgrades/` for the assessment,
plan, and a per-task record of what changed.

## Run it

1. Open [src/eShopLite.StoreFx/appsettings.json](src/eShopLite.StoreFx/appsettings.json) and replace
   `REPLACE_ME` with the database password. Nothing else needs changing.

2. ```
   dotnet run --project src/eShopLite.StoreFx
   ```

Then browse to the URL it prints.

Sign in as `alice` or `bob` — both are customers with existing order history. Credentials are in
[Demo logins](../../../docs/logins.md).

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
