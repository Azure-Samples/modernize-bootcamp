# Caldova Retail — Storefront (eShopLite.StoreFx)

A small ASP.NET MVC 5 storefront on .NET Framework 4.8, backed by Entity Framework 6 and SQL Server. It lists products and stores, handles sign-in, and keeps a cart. This is the customer-facing app in the Caldova Retail modernization scenario — see the [repository README](../../../README.md) for the bigger picture.

## Set the connection string

[Web.config](src/eShopLite.StoreFx/Web.config) pulls its connection string from `connectionStrings.config` using `configSource`. That file holds the SQL password, so it is gitignored and is never present in a fresh clone — **until you create it, every request returns HTTP 500, including the home page.**

From this folder, copy the template:

```powershell
Copy-Item ".\src\eShopLite.StoreFx\connectionStrings.config.example" `
          ".\src\eShopLite.StoreFx\connectionStrings.config"
```

Open the new file and replace `REPLACE_ME` with the password you were given. Leave the server, database, and user exactly as they are.

Editing `connectionStrings.config` restarts the app automatically, so a correction does not need an IIS Express restart. Never commit the file — the `.gitignore` entry is already in place, so leave it alone.

## Build, run, and sign in

Restoring packages, building with MSBuild, and launching under IIS Express are covered step by step in [Module 02](../../../labs/day-1/02-upgrade-dotnet-with-ghcp/Readme.md). Sign-in credentials are in [Demo logins](../../../docs/logins.md).
