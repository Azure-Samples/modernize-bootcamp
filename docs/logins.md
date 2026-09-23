# 🔑 Demo logins

The lab applications ship with seeded accounts. Whenever a module tells you to sign in, these are the credentials.

## Caldova storefront

| Username | Password | Role | Notes |
| --- | --- | --- | --- |
| `alice` | `Password1!` | Customer | Has existing order history |
| `bob` | `Password1!` | Customer | Has existing order history |

Either account works for the sign-in and cart checks the labs ask you to run. They are seeded on first run by [Configuration.cs](../src/app-modernization/caldova-retail-web-app/src/eShopLite.StoreFx/Migrations/Configuration.cs).

> ⚠️ These are throwaway credentials for a local sandbox, and the authentication behind them is deliberately insecure — salted SHA-1 password hashes. That is the "before" state the bootcamp migrates away from.
