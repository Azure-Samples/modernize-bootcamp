# Azure Deployment Plan

> **Status:** Ready for Validation

Generated: 2026-08-31

## 1. Project Overview

**Goal:** Reorder and enhance the bootcamp deployment lab, then add a post-data CI/CD challenge that builds the modernized application as a container, pushes it to the Lab 04 Azure Container Registry, and updates the single zone-redundant Azure Container App through GitHub Actions OIDC.

**Path:** Add Components

## 2. Requirements

| Attribute | Value |
| --- | --- |
| Classification | Development / training lab |
| Scale | Small, with bounded autoscaling |
| Budget | Cost-optimized where requirements permit |
| Subscription | Selected by each participant during bootstrap |
| Primary location | North Central US |
| Secondary location | Central US |

## 3. Components Detected

| Component | Type | Technology | Path |
| --- | --- | --- | --- |
| Storefront | Web application | .NET | `src/app-modernization/caldova-retail-web-app/` |
| Admin client | Desktop application | .NET Framework WinForms | `src/app-modernization/caldova-retail-admin-app/` |
| Deployment lab | Documentation | Markdown | `labs/04-deploy-to-azure/` |
| Data lab | Documentation | Markdown | `labs/05-modernize-data/README.md` |

The participant's modernized application shape may differ, so this lab provisions placeholder Container Apps and does not deploy workshop application code.

## 4. Recipe Selection

**Selected:** Bicep with Azure CLI orchestration from GitHub Actions

**Rationale:** Bicep provides an Azure-native, state-free recovery path. Resource-group-scoped deployments avoid granting the GitHub deployment identity subscription-wide Contributor access.

## 5. Architecture

**Stack:** Containers

| Component | Azure Service | Baseline |
| --- | --- | --- |
| Global HTTPS routing | Azure Front Door Premium | Private Link to one zone-redundant application origin |
| Application platform | Azure Container Apps workload-profile environment | Internal and zone-redundant; Central US default |
| Placeholder application | Azure Container App | 2-10 replicas, HTTP scaling, replaced by Lab 06 |
| Container images | Azure Container Registry | Basic |
| VM administration | Azure Bastion | Basic |
| Source/test servers | Azure Virtual Machines | Development-sized SKUs |
| Migration target | Azure SQL Database | Development SKU, private endpoint |
| Optional migration target | Azure SQL Managed Instance | Manually dispatched deployment |
| Migration service | Azure Database Migration Service | SHIR-based lab path |
| Secrets | Azure Key Vault | RBAC, bootstrap-generated VM credentials |
| Infrastructure identity | User-assigned managed identity | Lab 04 GitHub environment OIDC federation |
| Code deployment identity | User-assigned managed identity | Lab 06 GitHub environment OIDC federation |
| Platform logs | Log Analytics | Application-region workspace |

### Network boundaries

- Primary database VNet: `10.0.0.0/20`
- Secondary database VNet: `10.1.0.0/20`
- Application VNet: `10.20.0.0/20` in a workflow-selected zone-capable region; Central US by default
- VMs have no public IPs.
- Azure SQL public network access is disabled.
- The Container Apps environment is internal and Front Door reaches it through Private Link.
- The Container Apps environment is zone-redundant and the application maintains at least two replicas.

### Lab 06 CI/CD flow

1. A pull request that changes the retail app, Dockerfile, or workflow restores, builds, and tests the .NET 10 application, builds its container image, and performs a local `/health` smoke test. It does not authenticate to Azure or push an image.
2. A push to `main` repeats validation, signs into Azure with the dedicated Lab 06 OIDC identity, signs into ACR, and pushes an immutable `sha-<commit>` image tag.
3. The workflow resolves the pushed manifest digest and deploys `registry/repository@digest`, preventing a mutable tag from changing after approval.
4. The workflow configures the existing Container App to pull through its system-assigned managed identity, preserves its scale configuration, supplies a passwordless Azure SQL connection string, updates the image, waits for the revision to become healthy, and verifies the Front Door endpoint.
5. GitHub environment protection on `lab06-deploy` provides the deployment approval boundary.

### CI/CD RBAC

- The Lab 06 identity receives `AcrPush` (`8311e382-0749-4cb8-b61a-304f252e45ec`) at the registry scope.
- The Lab 06 identity receives `Container Apps Contributor` (`358470bc-b998-42bd-ab17-a7e34c199c0f`) at the single Container App scope.
- The Lab 06 identity receives Reader at the Front Door profile scope only so the release can resolve its smoke-test endpoint.
- The existing Lab 04 infrastructure identity is not reused for code deployment.
- The Container App system identity retains `AcrPull` at the registry scope.
- Lab 05 creates a contained Azure SQL user for the Container App managed identity and grants only the application database roles required by the retail workload.

## 6. Provisioning Limit Checklist

Participants must run the documented preflight and quota checks in their selected subscription before deployment. No Azure deployment is requested in this repository-change task.

| Resource type | Planned quantity | Quota/capacity action |
| --- | ---: | --- |
| `Microsoft.App/managedEnvironments` | 1 | Verify the selected application region supports Availability Zones |
| `Microsoft.App/containerApps` | 1 | Verify regional availability |
| `Microsoft.Compute/virtualMachines` | 2 | Verify selected VM-family vCPU quota in North Central US |
| `Microsoft.Network/bastionHosts` | 1 | Verify regional availability |
| `Microsoft.Sql/servers/databases` | 1 | Verify selected database SKU |
| `Microsoft.Sql/managedInstances` | 1 optional | Mandatory quota and subnet validation before manual workflow |
| `Microsoft.Cdn/profiles` | 1 | Verify Front Door Premium availability |
| `Microsoft.DataMigration/services` | 1 | Verify provider registration and regional availability |

## 7. Execution Checklist

### Phase 1: Planning

- Approved architecture and lab sequence captured.
- Bicep selected as the known-good implementation.
- North Central US remains the source/database VM default.
- Central US is the default application region because North Central US does not support Availability Zones.
- Workflow/bootstrap location parameters permit reuse in other supported regions.
- The new CI/CD lab targets only the modernized retail web app; the WinForms admin app remains in its later modernization lab.
- Pull requests validate without Azure access; pushes to `main` deploy to the protected environment.
- The Lab 06 workflow deploys only the single zone-redundant Container App.

### Phase 2: Execution

- [x] Refactor Lab 04 from two application regions to one parameterized, zone-redundant application region.
- [x] Retain Front Door Premium with one Private Link origin.
- [x] Add a dedicated Lab 06 OIDC identity and federated GitHub environments to bootstrap.
- [x] Add Bicep role assignments for `AcrPush` and `Container Apps Contributor`.
- [x] Change the Azure SQL database baseline name to `eShop` and update Lab 05 with managed-identity database grants.
- [x] Add a production multi-stage Dockerfile, `.dockerignore`, and `/health` endpoint to the known-good .NET 10 retail app.
- [x] Insert CI/CD as Lab 06 and renumber Application Insights, AI, and CLI to Labs 07, 08, and 09.
- [x] Add a guided participant workflow exercise and a complete GitHub Actions recovery workflow.
- [x] Update navigation, module numbers, architecture diagrams, bootstrap explanation, validation, rollback, and cleanup.
- [x] Update status to `Ready for Validation`.

### Phase 3: Validation

- [x] Invoke `azure-validate`.
- [ ] All validation checks pass.
  - [x] Bicep compilation and lint diagnostics.
  - [x] PowerShell and workflow YAML parsing.
  - [x] .NET Release build.
  - [x] Static RBAC and workflow-permission verification.
  - [x] Cross-file and lab-number consistency.
  - [ ] Container build and local smoke test; Docker is not installed in this authoring environment.
  - [ ] Azure authentication, policy evaluation, resource-group template validation, and what-if; these require participant bootstrap and a selected subscription.

### Static RBAC verification

- The Container App system identity receives `AcrPull`, scoped to the lab registry.
- The dedicated Lab 06 identity receives `AcrPush` at the registry scope and `Container Apps Contributor` at the single app scope.
- The Lab 06 identity also receives Reader at the Front Door profile scope for endpoint discovery; it receives no primary-resource-group read role.
- The GitHub deployment identity receives management-plane Contributor and Role Based Access Control Administrator only on the three lab deployment resource groups.
- The GitHub deployment identity receives Key Vault Secrets User only on the bootstrap vault.
- The participant receives Key Vault Secrets Officer only on the bootstrap vault so the bootstrap can create and later rotate the VM credentials.
- VM and SQL MI system identities have no data-plane permissions because this infrastructure-only lab does not use them yet. Later labs must add service-specific roles before using those identities.

## 8. Files to Generate

| File or folder | Purpose |
| --- | --- |
| `labs/04-deploy-to-azure/` | Single-region zone-redundant deployment challenge and diagram |
| `labs/05-modernize-data/` | Data lab plus passwordless application identity setup |
| `labs/06-deploy-code-with-github-actions/` | New CI/CD challenge |
| `labs/07-add-application-insights/` | Renumbered observability lab |
| `labs/08-add-ai-capabilities/` | Renumbered AI lab |
| `labs/09-modernize-with-cli/` | Renumbered admin app lab |
| `assets/scripts/Initialize-Lab04Repository.ps1` | Lab 04 and Lab 06 OIDC identities, RBAC bootstrap, Key Vault, and GitHub environments |
| `assets/scripts/Remove-Lab04Environment.ps1` | Scoped cleanup |
| `.github/workflows/lab04-deploy.yml` | Base deployment |
| `.github/workflows/lab04-deploy-sqlmi.yml` | Optional SQL MI deployment |
| `assets/solutions/lab06/lab06-retail-cicd.yml` | Known-good PR validation and main-branch deployment recovery file |
| `infra/lab04/student/` | Participant starter |
| `infra/lab04/complete/` | Refactored known-good modular Bicep |
| `labs/03-modernize-with-ghcp/sample-app/src/eShopLite.StoreFx/Dockerfile` | Known-good retail container build |
| `labs/03-modernize-with-ghcp/sample-app/.dockerignore` | Minimal container context |

## 9. Next Steps

> Current: Local validation complete; Azure-aware validation awaits a participant subscription and bootstrap.

Run the Lab 04 bootstrap in the selected participant subscription, then use the protected workflow to perform Azure template validation, policy checks, what-if, and deployment approval.

## 10. Validation Proof

| Check | Command run | Result | Timestamp |
| --- | --- | --- | --- |
| Bicep compilation | `Get-ChildItem .\infra\lab04 -Filter *.bicep -Recurse` with `az bicep build --stdout` | Pass: 23 files, zero diagnostics | 2026-08-31 |
| PowerShell syntax | PowerShell parser over `assets/scripts/*.ps1` | Pass: 2 scripts | 2026-08-31 |
| Workflow YAML syntax | PyYAML `safe_load` over `.github/workflows` and `assets/solutions` | Pass: 3 workflows | 2026-08-31 |
| Retail application build | `dotnet build .\labs\03-modernize-with-ghcp\sample-app\eShopLiteFx.sln --configuration Release` | Pass: zero warnings and zero errors | 2026-08-31 |
| Container build and smoke test | `docker build`, `docker run`, and `/health` probe | Deferred: Docker is not installed in the authoring environment | 2026-08-31 |
| Markdown local links | Relative-link existence check over Labs 04-09 and `infra/lab04` | Changed-lab links pass; 17 inherited screenshot references in Labs 08-09 remain absent from the source repository | 2026-08-31 |
| Diff whitespace | `git diff --check` | Pass | 2026-08-31 |
| Prohibited SQL authentication | Search for SQL administrator credential properties | Pass: no matches | 2026-08-31 |
| Stale lab references | Search for previous deployment/data paths and numbering | Pass: no matches | 2026-08-31 |
| Static RBAC | Reviewed Bicep role assignments and bootstrap CLI scopes | Pass: infrastructure and code-deployment identities are separated; workload roles are resource-scoped | 2026-08-31 |
| CI/CD security | Static assertions over `assets/solutions/lab06/lab06-retail-cicd.yml` | Pass: PR has no Azure token, Azure jobs use OIDC, digest deployment, system-identity pull, main-only release | 2026-08-31 |

Azure template validation, policy evaluation, quota checks, and what-if require the participant-selected subscription, bootstrapped resource groups, Key Vault secrets, and Entra administrator values. They remain enforced by the workflows and were not run during this repository-only change.
