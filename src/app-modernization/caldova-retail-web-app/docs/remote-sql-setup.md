# Connecting eShopLite to the remote SQL Server ("on-prem" simulation)

The app runs **locally** on each person's machine; the database lives on a **remote Windows
Server VM** running SQL Server 2016. This simulates an on-prem SQL Server, so the .NET upgrade
work happens locally without also having to migrate the database.

```
Each person's machine                 Azure VM (bootcampVM)
─────────────────────                 ─────────────────────
IIS Express :17490   ──TCP 1433───►   SQL Server 2016
eShopLite.StoreFx                     eShop database
```

The VM and its database are already set up. The firewalls allow any traffic arriving from inside
Azure, so most people connect with no setup at all — see
[Current access configuration](#current-access-configuration) for who that covers and who needs
their IP added.

---

# Getting connected

## Attendee: connect to the database

> The firewalls allow anything arriving from **inside Azure**. If your traffic reaches Azure
> through a corporate network client (Global Secure Access), an Azure VPN, or an Azure VM, you
> are already covered and need nothing but the password — start at step 1.
>
> If you connect straight from a home or public network with no VPN, your address will not be
> allowed yet. Step 1 will time out, and you will need to **send the VM owner your public IP**:
>
> ```powershell
> (Invoke-RestMethod 'https://api.ipify.org?format=json').ip
> ```
>
> Take that value in the same state you will actually work in — VPN on or off, Global Secure
> Access enabled or disabled — because changing any of those changes the address.

### 1. Test the connection first

Before cloning or building anything, confirm you can reach the database. Any PowerShell or
Command Prompt window — no admin, no repo:

```powershell
sqlcmd -S 20.118.204.47,1433 -U eshopapp -P '<password>' -d eShop -Q "SELECT COUNT(*) FROM [Product];"
```

Any number back means the connection works — skip to step 2. The exact count depends on what is
in the database at the time.

If it fails, see [If the connection fails](#if-the-connection-fails) below before continuing.

> SQL Server listens on the default port 1433, so `,1433` is optional — `-S 20.118.204.47`
> works too. When a port is given it is separated by a **comma**, not a colon.

### Or browse the database in VS Code

The **SQL Server** extension connects directly to the database, so you can browse tables and run
queries without cloning or running the app at all. It is also the easiest way to see what the
app wrote after placing an order.

Open the SQL Server extension (database icon in the Activity Bar) → **+ Add Connection**:

| Field | Value |
|---|---|
| Server name | `20.118.204.47,1433` |
| Database | `eShop` |
| Authentication type | SQL Login |
| User name | `eshopapp` |
| Password | (as given) |
| Trust server certificate | **Yes** |

The Database dropdown stays empty until the connection actually succeeds — type `eShop`
manually rather than waiting for it to populate. If it will not connect, the most common cause
is **Trust server certificate** not being set; the VM uses a self-signed certificate.

Once connected, expand the connection to see `Product`, `StoreInfo`, `User`, `Order`,
`OrderLine`, and `__MigrationHistory`.

### 2. Set up and run the app

Once the connection test passes, the rest of setup — cloning, NuGet restore, MSBuild, the
connection string file, and starting IIS Express — lives in the
[storefront README](../README.md). Follow that guide, and come back here only if the app cannot
reach the database.

---

## If the connection fails

### "A connection was successfully established with the server, but then an error occurred during the pre-login handshake"

Despite the wording this is **not** a TLS problem, and usually not a credential problem — that
error appears before the password is ever sent.

On a Microsoft-managed laptop the usual cause is the **Global Secure Access (GSA)** client.
GSA installs a network filter driver that intercepts outbound traffic and can route connections
destined for Azure VM public IPs into an Entra Private Access application whose connector
cannot reach the VM. The connection is accepted locally and then dropped, which produces this
error on any port.

Confirm it by asking GSA whether it is capturing the destination:

```powershell
& 'C:\Program Files\Global Secure Access Client\GSATracert\GsaTracert.exe' --host 20.118.204.47:1433 -n 1
```

If the output mentions **Entra Private Access application** and a **Connector**, GSA is
capturing the traffic.

**Workaround — disable the GSA filter driver.** Run in an **Administrator** PowerShell:

```powershell
Disable-NetAdapterBinding -Name '*' -ComponentID GlobalSecureAccessDriver
```

Verify every adapter now reads `False`:

```powershell
Get-NetAdapterBinding -AllBindings |
    Where-Object ComponentID -eq 'GlobalSecureAccessDriver' |
    Select-Object Name, Enabled
```

Retry the `sqlcmd` test from step 1. When you are finished working, restore it:

```powershell
Enable-NetAdapterBinding -Name '*' -ComponentID GlobalSecureAccessDriver
```

Notes:

- **Stopping the GSA services is not enough** and makes things worse — the filter driver keeps
  capturing packets with nothing to hand them to, turning connection resets into timeouts.
  Unbind the driver instead.
- **A reboot re-enables the driver**, so this is a per-session step.
- **Your public IP changes** when GSA is disabled, because traffic stops being tunneled through
  Microsoft's edge. This only matters if the owner has tightened the firewall rules to specific
  IPs — in that case send them your new IP, taken *after* disabling GSA.
- This has been observed to vary by device: some machines connect fine with GSA enabled.
  Always try step 1 first before disabling anything.

### The connection times out

If it hangs rather than returning an error, your address is most likely not permitted. That is
expected if you are connecting directly from a home or public network with no VPN — the
firewalls allow traffic from inside Azure, not arbitrary internet addresses.

Send the VM owner your public IP and ask them to add it:

```powershell
(Invoke-RestMethod 'https://api.ipify.org?format=json').ip
```

Take it in the state you will actually work in, since a VPN or Global Secure Access changes the
address.

### Corporate VPN

If your organisation provides a VPN, it is worth trying **both** states — connected and
disconnected — before concluding anything.

- Some networks only allow outbound database ports through the VPN, in which case connecting to
  it is what makes this work.
- Other clients (Global Secure Access being the example above) do the opposite and break the
  connection, so disconnecting is what helps.

Which applies depends on how your organisation routes traffic, so test rather than assume. Note
that connecting or disconnecting changes your public IP, which matters only if the owner has
tightened the firewall rules to specific addresses.

### "Login failed for user 'eshopapp'"

Good news — TCP and TLS both worked and you reached authentication. This is just a wrong
password or username.

### The app starts but throws a configuration error

`connectionStrings.config` is missing. See step 3.

---

## VM owner: restricting access to specific IPs (optional)

> **Ignore this for now.** The firewalls are deliberately open to a broad range and no per-person
> setup is needed. This section is kept only in case the rules ever have to be tightened.

To restrict access to named IPs, **all three** of the following must list every allowed address.
Each command *replaces* the list rather than appending, so always include your own IP.

Get the attendee's IP first — and note it must be taken **after** they disable GSA, if they
had to:

```powershell
(Invoke-RestMethod 'https://api.ipify.org?format=json').ip
```

```powershell
# 1. NIC-level NSG
az network nsg rule update -g app-data-modernize-bootcamp --nsg-name bootcampVM-nsg `
  -n AllowSql1433FromMyIp --source-address-prefixes <ip1> <ip2>

# 2. Subnet-level NSG  -- easy to miss; traffic must pass BOTH NSGs
az network nsg rule update -g app-data-modernize-bootcamp `
  --nsg-name vnet-centralus-1-snet-centralus-1-nsg-centralus `
  -n AllowSql1433FromMyIp --source-address-prefixes <ip1> <ip2>

# 3. VM Windows firewall  -- no RDP needed
az vm run-command invoke -g app-data-modernize-bootcamp -n bootcampVM `
  --command-id RunPowerShellScript `
  --scripts "Set-NetFirewallRule -DisplayName 'SQL 1433' -RemoteAddress <ip1>, <ip2>"
```

Verify Azure agrees the address is permitted:

```powershell
az network watcher test-ip-flow -g app-data-modernize-bootcamp --vm bootcampVM `
  --direction Inbound --protocol TCP --local 172.16.0.4:1433 `
  --remote <their-ip>:56789 --nic bootcampvm749
```

Expect `"access": "Allow"`.

> **There are two NSGs.** One is attached to the VM's NIC, the other to the subnet, and traffic
> must be permitted by both. Adding a rule to only one produces a silent timeout that looks
> exactly like a server problem.

> Never widen a rule to `Internet` / `0.0.0.0/0`. An internet-facing SQL port gets found and
> brute-forced quickly.

---

## Current access configuration

| Layer | Current setting |
|---|---|
| NIC NSG `bootcampVM-nsg` | `AllowSql1433` (`AzureCloud` tag) + `AllowSql1433FromMyIp` (owner's IP), port 1433 |
| Subnet NSG `vnet-centralus-1-snet-centralus-1-nsg-centralus` | the same two rules |
| VM Windows firewall rule `SQL 1433` | `Any` remote address |

Azure does not allow a service tag and an IP address in the same rule, which is why each NSG has
two rules.

**Who this covers automatically** — anyone whose traffic reaches Azure from inside Azure:

- Global Secure Access or a similar corporate client that tunnels through Microsoft's edge
- an Azure VPN connection
- another Azure VM

**Who needs their IP added** — anyone connecting directly from a home or public network with no
VPN. Their address is a plain ISP address, which the `AzureCloud` tag does not cover, so they
must send the owner the output of:

```powershell
(Invoke-RestMethod 'https://api.ipify.org?format=json').ip
```

The owner then adds it as described in the previous section. The `AllowSql1433FromMyIp` rule
exists for exactly this reason — it is the owner's own direct connection.

The trade-off of the `AzureCloud` rule is that port 1433 is reachable from any address inside
Azure, protected only by the `eshopapp` password. That is acceptable for a throwaway sandbox
holding sample data; tighten it (previous section) or delete the VM when the lab is done, and
rotate the password afterwards.

### Credentials to send an attendee

| Field | Value |
|---|---|
| Server | `20.118.204.47,1433` |
| Database | `eShop` |
| User | `eshopapp` |
| Password | send out-of-band |

The owner also needs the VM running:

```powershell
az vm start -g app-data-modernize-bootcamp -n bootcampVM
```

---

# How the environment was set up

Reference for anyone rebuilding this environment or debugging it. Nothing here needs doing to
use the app — these changes are already applied to the VM and the repo.

## Networking

| Layer | Change | Why |
|---|---|---|
| SQL Server | TCP/IP protocol enabled | Off by default on SQL Server Express; without it only local shared-memory connections work. |
| SQL Server | Fixed port `1433`, dynamic ports cleared | A static port is required so clients can connect without the SQL Browser service. |
| NIC NSG `bootcampVM-nsg` | Inbound allow, TCP 1433 | Azure denies all inbound by default. |
| Subnet NSG `vnet-centralus-1-snet-centralus-1-nsg-centralus` | Inbound allow, TCP 1433 | **Second NSG** — traffic must be permitted by both. |
| VM Windows firewall | Inbound rule `SQL 1433` | Third layer. |

This ran on port 14330 for a while, on the theory that some networks filter the default 1433.
That turned out not to be the cause of anything — the real problems were the missing subnet NSG
rule and Global Secure Access — so it was moved back to 1433, which is what tools expect.

The registry changes, run on the VM:

```powershell
$inst = 'MSSQL13.MSSQLSERVER'   # MSSQL13 = SQL Server 2016
$base = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$inst\MSSQLServer"

Set-ItemProperty "$base\SuperSocketNetLib\Tcp" -Name Enabled -Value 1
Set-ItemProperty "$base\SuperSocketNetLib\Tcp\IPAll" -Name TcpPort -Value '1433'
Set-ItemProperty "$base\SuperSocketNetLib\Tcp\IPAll" -Name TcpDynamicPorts -Value ''
Restart-Service MSSQLSERVER -Force

Get-NetTCPConnection -LocalPort 1433 -State Listen   # must return a row
```

The registry holds the *configured* port; SQL only picks it up on service restart. If the two
disagree, the service has not been restarted since the change.

## SQL Server authentication

Windows authentication does not work across machines, so the server was switched to **Mixed
Mode** and a dedicated SQL login created.

```powershell
# Mixed Mode: 2 = SQL + Windows. Requires a service restart.
Set-ItemProperty $base -Name LoginMode -Value 2
Restart-Service MSSQLSERVER -Force
```

```powershell
sqlcmd -S localhost -E -Q "CREATE LOGIN eshopapp WITH PASSWORD = '<password>', CHECK_POLICY = ON;"
sqlcmd -S localhost -E -d eShop -Q "CREATE USER eshopapp FOR LOGIN eshopapp; ALTER ROLE db_datareader ADD MEMBER eshopapp; ALTER ROLE db_datawriter ADD MEMBER eshopapp;"
```

`db_datareader` + `db_datawriter` only. The app just reads and writes rows, so it has no need
for `db_owner` or `sysadmin`.

## Database

The `eShop` database holds the product catalogue, stores, users, and order history. It already
exists on the VM — this section records how it was originally provisioned.

```powershell
sqlcmd -S localhost -E -Q "CREATE DATABASE eShop;"
sqlcmd -S localhost -E -Q "ALTER DATABASE eShop SET AUTO_CLOSE OFF;"
```

> The schema and seed script is not kept in this repository. If the database ever has to be
> rebuilt from scratch, get the current script from the data repository rather than recreating
> it by hand — the schema has moved on from earlier versions of this app.

Worth knowing: **`AUTO_CLOSE` is on by default in SQL Server Express.** Left on, the database
shuts down after the last connection closes and cold-starts on the next one, which makes the
app feel slow and fills the error log with `Starting up database` entries.

## Application configuration

The connection string moved out of `Web.config` so the SQL password is never committed:

```xml
<!-- Web.config -->
<connectionStrings configSource="connectionStrings.config" />
```

| File | Tracked in git | Contents |
|---|---|---|
| `Web.config` | yes | points at the external file via `configSource` |
| `connectionStrings.config` | **no** — gitignored | the real connection string and password |
| `connectionStrings.config.example` | yes | template with `Password=REPLACE_ME` |

The connection string itself:

```
Data Source=<vm-ip>,1433;Initial Catalog=eShop;User ID=eshopapp;Password=<password>;Encrypt=True;TrustServerCertificate=True;
```

`Encrypt=True` encrypts traffic over the public internet. `TrustServerCertificate=True` is
needed because SQL Server uses a self-signed certificate — acceptable for a sandbox, not for
production.

---

# Troubleshooting

Attendee-facing connection failures are covered in
[If the connection fails](#if-the-connection-fails). The notes below are for the VM owner.

### `Test-NetConnection` says the port is open, but connections still fail

`Test-NetConnection` is unreliable behind a network agent such as Global Secure Access. GSA
answers TCP handshakes locally, so it reports success even for ports where nothing is listening.

Sanity check by probing a port nothing uses:

```powershell
Test-NetConnection 20.118.204.47 -Port 23456
```

If that "succeeds", something local is intercepting connections and `Test-NetConnection` results
are meaningless. Test with a real SQL connection instead.

### Connection times out and every layer looks correct

Check **both** NSGs. The NIC NSG and the subnet NSG are separate resources, and a rule present
on only one produces a silent timeout:

```powershell
az network nsg rule list -g app-data-modernize-bootcamp --nsg-name bootcampVM-nsg -o table
az network nsg rule list -g app-data-modernize-bootcamp `
  --nsg-name vnet-centralus-1-snet-centralus-1-nsg-centralus -o table
```

### "Login failed for user 'eshopapp'"

Good news — TCP and TLS both worked and you reached authentication. Check the password, and
confirm Mixed Mode is on (`LoginMode = 2`), which requires a service restart to take effect.

### Checking what the server actually saw

```powershell
az vm run-command invoke -g app-data-modernize-bootcamp -n bootcampVM `
  --command-id RunPowerShellScript `
  --scripts "Get-Content 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Log\ERRORLOG' -Tail 40"
```

If failed attempts produce no entries at all, the traffic never reached SQL Server and the
problem is in the network path, not the database.

`az vm run-command` reaches the VM through Azure Resource Manager rather than the network path,
so it keeps working even when RDP and SQL do not. It is the most reliable way to inspect or fix
the VM when connectivity is broken.

---

# Notes for running this at scale

- **GSA behaviour varies by device.** At least one machine could connect with GSA enabled while
  another could not, with identical Azure configuration. Have attendees test the `sqlcmd`
  command first and only disable the driver if it fails.
- **Asking attendees to disable corporate security software is not ideal.** The durable fix is
  to have the Entra Private Access application scoped so it does not capture the VM's IP — a
  tenant configuration change.
- **Corporate egress IPs are not stable.** Behind GSA an address can change every few minutes,
  so per-IP firewall rules are unworkable for those users. That is why the current
  configuration uses the broad `AzureCloud` range instead.
- **More robust alternatives**, in rough order of setup cost:
  - **Azure Bastion tunnel** — tunnels TCP over HTTPS/443, which corporate networks allow.
    Attendees keep the app local. Requires Bastion Standard SKU and RBAC on the VM.
  - **Point-to-site VPN** — most faithful to real on-prem, but P2S clients often conflict with
    corporate network agents.
  - **Per-attendee VM** — attendees RDP in and run both app and database there. Most reliable,
    but the upgrade work no longer happens on their own machine, and a shared VM is limited to
    two concurrent RDP sessions without RDS licensing.
