# eShopLite.AdminFx

A .NET Framework 4.8 WinForms internal admin tool for eShopLite: staff can view and edit the product catalog against the Products API, and browse a read-only list of recent orders. It exists as an upgrade sandbox — legacy `.csproj`, `packages.config`, `App.config`, and Newtonsoft.Json are all deliberate starting points.

App inherited from [Module 9 of the Modernize Monolith Workshop](https://github.com/Azure-Samples/modernize-monolith-workshop/blob/main/9-migrate-winforms/README.md).

## Build and run

Needs MSBuild (Build Tools for Visual Studio 2022 or the full IDE) and `nuget.exe` — no IIS, no database. Run from this folder:

```powershell
# Restore Newtonsoft.Json into packages\ (not committed)
Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "$env:TEMP\nuget.exe" -UseBasicParsing
& "$env:TEMP\nuget.exe" restore ".\eShopLiteAdminFx.sln"

# Build
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
& $msbuild ".\eShopLiteAdminFx.sln" /t:Build /p:Configuration=Debug /v:minimal

# Run
.\eShopLite.AdminFx\bin\Debug\eShopLite.AdminFx.exe
```

`App.config` points the catalog at a Products API on `https://localhost:7102/`. When that is not running the app falls back to `Data/product-cache.json`, so it still starts and lists products. Orders always come from `Data/orders.json`.

## Sign in

The app opens with a login dialog. Seed accounts live in [eShopLite.AdminFx/Data/users.json](eShopLite.AdminFx/Data/users.json):

| Username | Password | Role | Can edit products |
| --- | --- | --- | --- |
| `admin` | `admin123` | Editor | Yes |
| `supportdeskagent` | `supportdeskagent` | Reader | No |

These are throwaway demo credentials for a local sandbox. The auth is intentionally insecure — unsalted SHA1 hashes in a JSON file, a shared API key, and permission checks that only gray out buttons in the UI — because it is the "before" state for a migration to Microsoft Entra ID.
