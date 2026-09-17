# Caldova Retail — Storefront (eShopLite.StoreFx)

A small ASP.NET MVC 5 (.NET Framework 4.8) storefront that lists products and stores, backed by Entity Framework 6 and SQL Server. This is the customer-facing app in the Caldova Retail modernization scenario — see the [repository README](../../README.md) for the bigger picture.

App inherited from [module 2 of Azure-Samples/modernize-monolith-workshop](https://github.com/Azure-Samples/modernize-monolith-workshop/tree/main/2-upgrade-dotnet/2-upgrade-with-ghcp-modernization-app).

**The app runs locally on your machine; the database does not.** It lives on a remote Windows Server VM running SQL Server 2016, which simulates an on-prem database — so the .NET upgrade work happens locally without also having to migrate the data.

```
Your machine                          Azure VM (bootcampVM)
────────────                          ─────────────────────
IIS Express :17490   ──TCP 1433───►   SQL Server 2016
eShopLite.StoreFx                     eShop database
```

The VM and its database are already set up — you do not create or seed a database. You do need
**the SQL password**, which is handed out separately. Full details, including firewall access and
connection troubleshooting, are in [docs/remote-sql-setup.md](docs/remote-sql-setup.md).

## Pre-req

Everything below must be done in order before the app will start. Do not skip steps.

> **Where to run these commands.** Unless a step says otherwise, run every PowerShell command from
> this folder (`app-modernization/caldova-retail-web-app`). From a fresh clone:
>
> ```powershell
> cd app-data-modernize\app-modernization\caldova-retail-web-app
> ```

---

### 1. Required Software

Install all of the following before doing anything else. The full Visual Studio 2022 IDE is **not** required — the lightweight **Build Tools for Visual Studio 2022** is sufficient and is the recommended install for this demo.

| Software | Version | Why it is needed |
|---|---|---|
| [Build Tools for Visual Studio 2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) | 17.x or later | Provides MSBuild for .NET Framework 4.8 builds (no IDE needed) |
| [IIS Express](https://learn.microsoft.com/en-us/iis/extensions/introduction-to-iis-express/iis-express-overview) | 10.x | The web server that hosts the app locally |
| [sqlcmd utility](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility) | Any current | Used in step 3 to prove you can reach the remote database |
| [VS Code](https://code.visualstudio.com/) | Any current | The editor this project is set up for |
| [IIS Express extension for VS Code](https://marketplace.visualstudio.com/items?itemName=warren-buckley.iis-express) | Any current | Lets VS Code launch and manage IIS Express |
| [SQL Server extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-mssql.mssql) | Any current | Optional — browse the remote tables and run queries without leaving the editor |

> **You do not install a database.** There is no LocalDB, no SQL Server Express, and no local
> instance of any kind. The database already exists on the remote VM. What you need instead is
> the **SQL password** for the `eshopapp` login — get it from the workshop organiser before you start.

> **Installing Build Tools for Visual Studio 2022:**
>
> 1. Run the installer and select the **"Web development build tools"** workload. This installs MSBuild with .NET Framework targeting support, the .NET Framework 4.8 targeting pack, and Web Deploy build targets — everything needed to compile this project.
> 2. IIS Express is **not** included in Build Tools. Download it separately from the link above.
>
> **Already have the full Visual Studio 2022 IDE?** It also works. The MSBuild path will be different — see step 2.

---

### 2. Verify MSBuild is Available

Open a PowerShell terminal and run the path that matches your install:

```powershell
# Build Tools for Visual Studio 2022 (recommended)
Test-Path "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
```

Expected output: `True`

If you installed the **full Visual Studio 2022 IDE** instead, the path uses `Program Files` (not `Program Files (x86)`) and includes the edition name:

```powershell
# Full VS 2022 — Enterprise
Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe"

# Full VS 2022 — Professional
Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe"

# Full VS 2022 — Community
Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
```

If every path returns `False`, Build Tools (or Visual Studio) is either not installed or the **"Web development build tools"** workload was not selected. Re-run the installer and add that workload.

---

### 3. Verify You Can Reach the Database

Do this **before** building anything. If your machine cannot reach the VM, nothing later in this guide will work, and the fix may involve someone else adding your IP address.

Open a PowerShell terminal and run, substituting the password you were given:

```powershell
sqlcmd -S 20.118.204.47,1433 -U eshopapp -P '<password>' -d eShop -Q "SELECT COUNT(*) FROM [Product];"
```

Expected output — any number back means the connection works. The exact count depends on what is in the database at the time:

```
-----------
         12

(1 rows affected)
```

> SQL Server listens on the default port 1433, so `,1433` is optional. When a port is given it is separated by a **comma**, not a colon.

**If the command hangs or times out:** your address is probably not permitted by the firewall. This is expected on a home or public network with no VPN.

**If you get "an error occurred during the pre-login handshake":** on a Microsoft-managed laptop this is usually the Global Secure Access client, not TLS and not your password.

Both cases, plus the exact workarounds, are covered in [docs/remote-sql-setup.md](docs/remote-sql-setup.md). Resolve this before continuing.

**If `sqlcmd` is not recognised:** install the [sqlcmd utility](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility). Alternatively, skip it and test the connection with the **SQL Server** extension in VS Code — server `20.118.204.47,1433`, database `eShop`, SQL Login `eshopapp`, and **Trust server certificate** set to **Yes** (the VM uses a self-signed certificate).

---

### 4. Download nuget.exe

This project uses the classic `packages.config` NuGet format. Visual Studio 2022 does **not** include `nuget.exe` by default, so you need to download it manually.

Open a PowerShell terminal and run the following command exactly as written:

```powershell
Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "$env:TEMP\nuget.exe" -UseBasicParsing
```

Verify the download succeeded:

```powershell
Test-Path "$env:TEMP\nuget.exe"
```

Expected output: `True`

> `$env:TEMP` is a Windows environment variable that points to your user temporary folder (usually `C:\Users\<YourUsername>\AppData\Local\Temp`). The file only needs to exist for the restore step below — you do not need to add it to your PATH permanently.

---

### 5. Restore NuGet Packages

The project's dependencies (Autofac, Entity Framework, ASP.NET MVC, etc.) are not stored in the repository. You must restore them before building.

From this folder, run:

```powershell
& "$env:TEMP\nuget.exe" restore ".\eShopLiteFx.sln"
```

You should see output listing each package being downloaded and added to the `packages` folder, ending with a line similar to:

```
Installed:
    24 package(s) to packages.config projects
```

**If you see an error like `Unable to find version X of package Y`:**

- Check your internet connection.
- Re-run the same command. NuGet restore is safe to run multiple times.

**If you see `nuget.exe` is not found:**

- Go back to step 4 and make sure the download completed successfully.

---

### 6. Build the Project with MSBuild

Now compile the project. This creates the `bin` folder with all the application DLLs that IIS Express needs.

First, set a variable pointing to MSBuild. Use the path that matches your install:

```powershell
# Build Tools for Visual Studio 2022 (recommended)
$msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"

# Full VS 2022 IDE — replace Enterprise with Professional or Community if needed
# $msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
```

Then run the build:

```powershell
& $msbuild ".\eShopLiteFx.sln" /p:Configuration=Debug /v:minimal
```

A successful build ends with output like:

```
eShopLite.StoreFx -> ...\src\eShopLite.StoreFx\bin\eShopLite.StoreFx.dll
```

Verify the `bin` folder was created:

```powershell
Test-Path ".\src\eShopLite.StoreFx\bin"
```

Expected output: `True`

**If the build fails with errors about missing assemblies:**

- The package restore in step 5 may have been incomplete. Run the `nuget.exe restore` command again, then retry the build.

**If the build fails with `error MSB3644: The reference assemblies for .NET Framework 4.8 were not found`:**

- The .NET Framework 4.8 targeting pack was not included in the Build Tools install. Re-run the Build Tools installer, select the **"Web development build tools"** workload, and make sure **.NET Framework 4.8 targeting pack** is checked under Individual components. Then retry the build.

---

### 7. Create Your Connection String File

The SQL password lives in `connectionStrings.config`, which is **gitignored** and therefore not in a fresh clone. [Web.config](src/eShopLite.StoreFx/Web.config) references it with `configSource`, and ASP.NET resolves that when the application starts — so **no page will load until you create it. Every request returns HTTP 500, including the home page.**

From this folder, copy the template:

```powershell
Copy-Item ".\src\eShopLite.StoreFx\connectionStrings.config.example" `
          ".\src\eShopLite.StoreFx\connectionStrings.config"
```

Open the new file and replace `REPLACE_ME` with the password you were given. The rest of the connection string is already correct — do not change the server, database, or user.

Verify the file exists:

```powershell
Test-Path ".\src\eShopLite.StoreFx\connectionStrings.config"
```

Expected output: `True`

> Never commit this file. It is already listed in `.gitignore`, so leave that entry alone.

---

### 8. Configure IIS Express in VS Code

VS Code uses a file called `iisexpress.json` to know which folder to host and on which port. This file must point to the **project folder** (not the repository root or the solution folder).

> **This is the one file that does not live in this folder.** The IIS Express extension reads it from
> the root of whatever folder you opened in VS Code, so its `path` value is written relative to the
> repository root — not relative to this README.

Open the file at `.vscode\iisexpress.json` at the repository root, i.e. `c:\Users\<you>\app-data-modernize\.vscode\iisexpress.json`.

The file must contain **exactly** this content:

```json
{
  "port": 17490,
  "path": "./app-modernization/caldova-retail-web-app/src/eShopLite.StoreFx",
  "clr": "v4.0",
  "protocol": "http"
}
```

Key points:

- `path` must point to the folder that contains `Web.config` and the `bin` folder — that is `eShopLite.StoreFx`.
- `clr` must be `"v4.0"` — the app targets .NET Framework 4.8 which runs on CLR v4.
- `port` can be any unused port. `17490` is the default configured here.

**If `.vscode\iisexpress.json` does not exist:**

Create the `.vscode` folder at the repository root if it does not already exist, then create `iisexpress.json` inside it with the exact content shown above.

---

### 9. Start the App with IIS Express

> **Before you start:** steps 6 and 7 must both be done. Without the build there is no `bin`
> folder and every request returns a 500; without `connectionStrings.config` ASP.NET cannot
> resolve its `configSource` at startup and every request returns a 500 too — including the
> home page.

1. Open VS Code with the repository root folder (`app-data-modernize`) as the open folder.
2. Open the Command Palette: press `Ctrl+Shift+P`.
3. Type `IIS Express: Start Website` and select it.
4. IIS Express will start and register the URL `http://localhost:17490/`.
5. Open a browser and navigate to: `http://localhost:17490/`

The home page should load, and the **Products** page should list the catalogue served from the VM. If products appear, your connection string and database access are both working.

Sign in with `alice` / `Password1!` (Admin, Manager) or `bob` / `Password1!` (Employee).

---

### Troubleshooting

#### iisexpress.json — Verifying and correcting the path

The IIS Express VS Code extension reads `.vscode\iisexpress.json` at the **repository root** to determine which folder to host. If that file is missing, has the wrong path, or was auto-generated by VS Code pointing to the repository root instead of the project folder, the app will either fail to start or return a 403 error.

**File location:** `.vscode\iisexpress.json` — this folder sits at the root of the folder you opened in VS Code (e.g. `c:\Users\<you>\app-data-modernize\.vscode\iisexpress.json`), **not** inside this app folder.

**Required content:**

```json
{
  "port": 17490,
  "path": "./app-modernization/caldova-retail-web-app/src/eShopLite.StoreFx",
  "clr": "v4.0",
  "protocol": "http"
}
```

**The `path` value must point to the folder that contains `Web.config`** — that is `eShopLite.StoreFx`. Common mistakes:

| Wrong value | Problem |
|---|---|
| `"."` or `"./"` | Points to the repository root — IIS gets no app to host |
| `"./app-modernization"` or `"./app-modernization/caldova-retail-web-app"` | Points to a parent or the solution folder — still no `Web.config` |
| `"./src/eShopLite.StoreFx"` | Missing the subfolder prefix — path does not resolve |

After correcting the file, stop IIS Express (Command Palette → `IIS Express: Stop Website`) and start it again.

---

#### HTTP 403.14 — Directory Listing Denied

**Cause:** The `path` in `iisexpress.json` is pointing to the wrong folder (e.g. the repository root or the solution folder instead of the project folder).

**Fix:** Open `.vscode\iisexpress.json` and make sure `path` is set to `./app-modernization/caldova-retail-web-app/src/eShopLite.StoreFx` exactly as shown in step 8.

---

#### HTTP 500.0 — Internal Server Error on startup

**Cause:** The `bin` folder does not exist or is empty — the project has never been compiled. ASP.NET cannot load the application assemblies.

**Fix:** Run steps 5 and 6 (NuGet restore then MSBuild build). After the build completes, stop IIS Express and start it again.

---

#### HTTP 500 with "Could not load file or assembly 'Autofac'" (or any other package DLL)

**Cause:** NuGet packages were not restored before building, so the DLLs are missing from the `bin` folder.

**Fix:**

1. Delete the `bin` folder at `src\eShopLite.StoreFx\bin` if it exists.
2. Re-run the NuGet restore (step 5).
3. Re-run the MSBuild build (step 6).
4. Restart IIS Express.

---

#### IIS Express starts but the browser shows "This site can't be reached"

**Cause:** The browser is not connecting to the correct port, or IIS Express did not start successfully.

**Fix:**

1. Confirm the port in `.vscode\iisexpress.json` — the default is `17490`.
2. Navigate to `http://localhost:17490/` (not `https`).
3. Check the VS Code output panel (View → Output → IIS Express) for any start-up errors.
4. If another process is using port 17490, change the `port` value in `iisexpress.json` to another unused port (e.g. `44300`) and restart.

---

#### HTTP 500 — "Unable to open configSource file 'connectionStrings.config'"

**Cause:** Step 7 was skipped. The file holds the SQL password, is gitignored, and is never present in a fresh clone.

**Fix:** Copy `connectionStrings.config.example` to `connectionStrings.config` and fill in the password — see step 7.

---

#### The app starts but the Products page errors or is empty

**Cause:** The app cannot reach the remote database, or the password in `connectionStrings.config` is wrong.

**Fix:**

1. Re-run the `sqlcmd` test from step 3. If that fails, the problem is connectivity or credentials, not the app.
2. Confirm `REPLACE_ME` in `connectionStrings.config` was actually replaced with the real password.
3. Editing `connectionStrings.config` restarts the app automatically, so there is no need to restart IIS Express after a correction.

This app does **not** create or seed its database. [Global.asax.cs](src/eShopLite.StoreFx/Global.asax.cs) calls `Database.SetInitializer<StoreDbContext>(null)`, which deliberately disables Entity Framework Code First so it never tries to create or migrate the shared remote database.

---

#### "sqlcmd" is not recognised as a command

The sqlcmd utility is not installed. See step 3 for the install link and the VS Code alternative.

---

#### nuget.exe restore fails with "Access to the path is denied"

The current user does not have write access to the `packages` folder location.

**Fix:** Run the PowerShell terminal as Administrator, or change the output path in the restore command to a folder where you have write permissions.

---

#### MSBuild error MSB4019 — The imported project Microsoft.WebApplication.targets was not found

**Cause:** The **"Web development build tools"** workload was not selected when Build Tools for Visual Studio 2022 was installed.

**Fix:** Open the Visual Studio Installer, select **Modify** on Build Tools for Visual Studio 2022, check the **"Web development build tools"** workload, and install. Then retry the MSBuild step.
