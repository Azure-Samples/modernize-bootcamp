# Bootcamp Deployment Export Plan

> **Status:** Ready for Validation

## SQL Managed Instance default amendment

- Make `sqlMi` the default AZD and direct-deployment database mode.
- Prefer Freemium General Purpose v2 (Gen5, 4 vCores, 64 GB, license included).
- Allow instructor automation to select paid General Purpose without a separate
  confirmation prompt when Freemium is unavailable.
- Retain Microsoft Entra-only authentication.
- Accept only an optional Entra administrator user principal name at the AZD
  and direct-deployment interfaces, resolve its required object ID before
  Bicep runs, and default to the signed-in user when the name is omitted.
- Enable the SQL MI public endpoint without broad NSG ingress. Participants
  separately allow only their current public IPv4 `/32` on TCP 3342.
- Keep `azureSql` available as an explicit alternative.

The remainder of this plan records the original export work.

## Multi-subscription naming hardening

The exported package now uses a shared eight-character deterministic suffix
derived from subscription resource ID, environment name, and prefix.

- Globally scoped Key Vault, ACR, SQL server, SQL MI, and Front Door endpoint
  names use the suffix.
- Resource-group-scoped names retain the same suffix for environment clarity.
- Key Vault prefix truncation is reduced to keep the maximum generated name at
  24 characters.
- Bicep entry points require exactly eight suffix characters.
- Cleanup accepts exactly eight lowercase alphanumeric characters, matching
  Bicep `uniqueString()` output.
- AZD pre-provisioning, direct deployment, and cleanup share a prefix contract:
  3-18 lowercase alphanumeric characters with optional single internal
  hyphens.
- The standalone bootstrap entry point now enforces the shared prefix length
  and exact eight-character suffix length.
- `LAB04_SUFFIX` and all automation consumers remain unchanged.

## Goal

Export the Lab 04 Azure deployment into this repository as a self-contained
package supporting both Azure Developer CLI (`azd`) and direct Bicep
deployment.

## Planned scope

- AZD project configuration and parameter mapping.
- Subscription-scoped Bicep entry point and all transitive modules.
- Pre-provision and direct-deployment PowerShell scripts.
- Optional GitHub OIDC setup and deployment workflow.
- Deployment, security, troubleshooting, and component documentation.
- Local validation of Bicep, PowerShell, YAML, JSON, links, and AZD structure.

## Constraints

- Do not copy credentials, local AZD environments, generated artifacts, or
  deployment state.
- Do not deploy Azure resources from this export task.
- Preserve any unrelated files already present in this repository.

## Analysis

### Destination

- `C:\code\bootcamp_deployment` exists and currently contains only this
  `.azure` plan.
- It is not currently a Git repository.
- Export mode is **NEW standalone deployment package**.

### Source and recipe

- Source: the current Lab 04 implementation in
  `app-data-modernize`.
- Recipe: AZD with a subscription-scoped Bicep entry point, plus a direct
  Azure CLI/PowerShell deployment path.
- Database modes: mutually exclusive `sqlMi` (default) and `azureSql`.

### Export manifest

| Destination | Content |
| --- | --- |
| `azure.yaml` | Infrastructure-only AZD project |
| `infra/main.bicep` | Subscription-scoped composition entry point |
| `infra/main.parameters.json` | AZD environment-to-Bicep parameter mapping |
| `infra/hooks/preprovision.ps1` | Secure AZD preparation and credential handling |
| `infra/Deploy-Lab04.ps1` | Validate, what-if, direct deploy, Private Link approval, and smoke test |
| `infra/lab04/complete/*.bicep` | Bootstrap, primary, secondary, and global compositions |
| `infra/lab04/complete/modules/*.bicep` | All transitive resource modules |
| `scripts/Configure-Lab04GitHub.ps1` | Optional GitHub OIDC, identities, RBAC, environments, and variables |
| `scripts/Remove-Lab04Environment.ps1` | Exact-scope resource-group cleanup |
| `.github/workflows/lab04-deploy.yml` | Protected GitHub OIDC provisioning workflow |
| `README.md` | Standalone quick start, components, security notes, and architecture diagram |
| `docs/DEPLOYMENT.md` | AZD and direct Bicep instructions, OIDC, reruns, and diagnostics |

Student exercise files, unrelated labs, local `.azure/<environment>` state,
credentials, generated ARM JSON, and deployment outputs will not be copied.

## Architecture

The export provisions:

1. Bootstrap resource group with Key Vault and managed identities.
2. Primary resource group with database VNet, Bastion, two private VMs, ACR,
   DMS, and Azure SQL when selected.
3. Secondary resource group with database/application VNets, monitoring,
   internal zone-redundant Container Apps, and SQL MI when selected.
4. Global resource group with Front Door Premium and an exact-match Private
   Link origin to the internal Container Apps environment.
5. Optional GitHub OIDC with separated preview/deploy and build/deploy
   identities and protected deployment environments.

## Execution steps

1. Create the destination folder structure without modifying the source.
2. Copy the exact deployment dependency set.
3. Adapt repository-relative script and documentation paths for the standalone
   layout.
4. Write the standalone README with AZD, direct Bicep, GitHub OIDC, cleanup,
   security caveats, Landing Zone recommendation, and a Mermaid diagram.
5. Validate the exported package.
6. Set this plan status to `Ready for Validation`, run `azure-validate`, and
   record results. No Azure deployment will be executed.

## Role Assignment Verification

- **Key Vault administrator:** `Key Vault Secrets Officer` scoped to the
  exported Key Vault for the selected Entra administrator.
- **Code build identity:** `AcrPush` scoped to the exported registry.
- **Container App system identity:** `AcrPull` scoped to the exported registry.
- **Code deployment identity:** `Container Apps Contributor` scoped to the
  exported Container App and `Reader` scoped to the Front Door profile.
- **Optional infrastructure workflow identities:** the GitHub setup script
  separates preview and deployment identities; preview receives Reader on the
  four lab resource groups, while deployment receives the narrow custom
  subscription deployment role and mutation rights only on those resource
  groups.
- Role assignments use deterministic GUID names and explicit
  `principalType`.

The exported application placeholder does not access data services, so it does
not require database data-plane roles.

## Section 7: Validation Proof

| Check | Result |
| --- | --- |
| Bicep compilation | Pass: all 21 exported `.bicep` files compiled with Azure CLI |
| PowerShell parsing | Pass: all 4 exported `.ps1` files parsed without errors |
| YAML and JSON | Pass: `azure.yaml`, workflow YAML, and parameter JSON parsed |
| Documentation links | Pass: every local Markdown link resolves |
| Dependency fidelity | Pass: all 21 complete implementation files match the source hashes |
| Manifest and exclusions | Pass: required files present; no student tree, unrelated labs, local AZD state, or application solution files |
| Secret-pattern scan | Pass: no credentials, private keys, tokens, or SQL password properties detected |
| AZD package | Pass: `azd package --no-prompt` completed successfully |
| AZD schema | Pass: Azure AZD schema validation reported `azure.yaml` valid against the stable schema |
| Tool authentication | Pass: AZD and Azure CLI authentication checks succeeded |
| Bicep lint | Pass: `az bicep lint --file infra/main.bicep` returned no diagnostics |
| Static RBAC review | Pass: Key Vault, ACR push/pull, Container App deployment, and Front Door read assignments are least-scope for their intended operations |
| Multi-subscription suffix | Pass: shared suffix is eight deterministic characters seeded by subscription resource ID, environment name, and prefix |
| Global uniqueness coverage | Pass: Key Vault, ACR, Azure SQL server, SQL MI, and Front Door endpoint names all include the shared suffix |
| Maximum name lengths | Pass: worst-case Key Vault 24/24, ACR 22/50, SQL server 23/63, SQL MI 22/63, Front Door endpoint 21/46, Container App 25/32 |
| Suffix contracts | Pass: all Bicep entry points require eight characters; cleanup accepts eight lowercase alphanumeric characters; no legacy shorter-suffix assumptions remain |
| Prefix contracts | Pass: AZD, direct deployment, and cleanup share a case-sensitive 3-18 character lowercase contract; leading, trailing, repeated hyphens and invalid characters are rejected |
| Standalone bootstrap contract | Pass: bootstrap enforces prefix length and an exact eight-character suffix |
| Naming-updated compilation | Pass: all 21 Bicep files compiled; entry point lint returned no diagnostics |
| Naming-updated scripts | Pass: all 4 PowerShell scripts parsed without errors |
| Naming-updated AZD package | Pass: `azd package --no-prompt` completed; generated local environment state was removed afterward |
| Naming-updated AZD schema | Pass: `azure.yaml` remains valid against the stable schema |
| Naming metadata and safety | Pass: YAML/JSON, documentation links, secret scan, excluded-content scan, and zero local AZD state |
| SQL administrator input scripts | Pass: AZD hook and direct deployment script parse without errors; only the optional UPN is exposed and the object ID is resolved internally |
| SQL administrator Bicep contract | Pass: entry point builds; entry point and both SQL modules lint with zero diagnostics; Entra-only login and SID properties remain intact |
| Updated AZD package | Pass: `azd package --no-prompt` completed; generated local environment state was removed afterward |

Azure deployment, policy evaluation, quota checks, and runtime verification were
not executed because this task exports a reusable package rather than deploying
it. The importing repository must run validation/what-if against its selected
subscription and regions before deployment.
