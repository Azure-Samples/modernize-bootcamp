# ☁️ Lab 04: Design the Azure Foundation with GitHub Copilot

In Module 3, you set up the app's code to use Azure services, such as reading its database password from Key Vault. Those services do not exist yet. In this module, you use GitHub Copilot to write the infrastructure as code (Bicep files) for them, and to build the secure cloud foundation the app will be deployed into.

> 🎯 **This module: build the cloud foundation the app will run on.** Module 3 changed the **app's code**. This module designs the **Azure resources** around it: the networks, databases, Key Vault, and container hosting the app needs. You will work with GitHub Copilot in agent mode to write them as Bicep files.

The same foundation also supports the database migration in later modules, so it includes the servers, private network connections, and database targets that migration needs.

Your instructor has already set up the real Azure environment used by the later labs, so **you will not deploy the Bicep you write**. The goal is to practice designing infrastructure with GitHub Copilot while you stay in charge of the decisions. A tested, finished version of the Bicep is included so you can compare your work. Expect some differences: Copilot does not produce the exact same output every time, so your files will not match the finished version line for line.

## 🗺️ How This Lab Works

If you have not designed Azure infrastructure before, here is the whole process in plain terms:

- **Infrastructure as code (IaC)** means describing Azure resources (networks, databases, Key Vaults, container hosting) in files instead of clicking through the Azure portal. The files can be reviewed, versioned, and redeployed the same way every time.
- **Bicep** is Azure's IaC language. Each `.bicep` file declares the resources to create and how they connect.
- **The app tells you what to build.** In Module 3, Copilot wired the app to use Azure services through configuration, for example reading its database password from **Key Vault**. Each of those settings needs a real Azure resource behind it. If the app expects a Key Vault, the foundation must include one. If the app stores shopping carts in **Redis** so they survive across multiple app instances, the foundation must include a Redis cache.
- **The requirements tell you how to build it.** The required architecture and non-negotiable rules below cover security, networking, and resilience: private networking, no public IPs on VMs, no stored passwords, and at least two app replicas.

You will work through four steps with GitHub Copilot, and you approve each one before moving on:

1. **Explore:** Copilot reads the repository and lists what the app needs from Azure and what the requirements demand.
2. **Plan:** Copilot proposes the resources, networks, and identities, and how they map to those needs. You review and correct the plan.
3. **Generate:** Copilot writes the Bicep files for the approved plan, and you check that they build.
4. **Review:** Copilot reviews the Bicep against the plan and requirements. You decide which findings to fix, then compare your design with a known-good implementation.

This lab takes approximately **90-120 minutes**.

## 🎯 Objectives

By the end of this lab, you will be able to:

- map the Azure settings the app reads to the Azure resources that must exist to support them
- turn a detailed workload brief into a reviewed infrastructure plan
- compare container compute options and justify Azure Container Apps for this workload
- separate application, migration, and database network boundaries
- design bounded autoscaling and multi-region application resilience
- guide GitHub Copilot from an approved plan to a Bicep implementation
- identify where lab constraints require deeper production architecture review

## 🧭 Where This Fits

The earlier labs assessed and modernized the application. This lab designs the Azure platform that application now expects.

You design the foundation **for the storefront**, but you do not deploy the storefront in this module. The preprovisioned Container App runs a placeholder image so the platform can be checked on its own first. On Day 2, you will deploy the storefront onto the foundation you are about to design.

## 🏗️ Required Final Architecture

![Target Azure architecture: Front Door routes HTTPS traffic over Private Link to the Container App in the application VNet; the peered database VNets hold Azure Bastion, the Windows and Ubuntu VMs, the Azure SQL private endpoint, and the optional SQL MI; GitHub Actions deploys Bicep through a scoped managed identity](./images/azure-architecture.png)

> [!IMPORTANT]
> **This is a workshop architecture, not a universal production reference
> architecture.** Some topology, region, SKU, service-boundary, and access
> decisions were selected to fit lab time, cost, subscription limits, and the
> learning sequence. For a production implementation, evaluate an
> [Azure landing zone](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
> as the platform baseline for governance, identity, security, connectivity,
> management, and workload subscriptions. Then review the workload against the
> [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
> and your organization's requirements. Networking and architecture decisions
> must be thoroughly reviewed for reliability, resiliency, security, cost,
> operational excellence, performance, failure modes, and recovery objectives
> before deployment.

### Network baseline

| VNet | Region | Address space | Purpose |
| --- | --- | --- | --- |
| Primary database | North Central US | `10.0.0.0/20` | Bastion, VMs, Azure SQL private endpoint |
| Secondary database | Central US | `10.1.0.0/20` | SQL Managed Instance delegated subnet |
| Application | Central US by default | `10.20.0.0/20` | Internal, zone-redundant Container Apps environment |

The application location remains a parameter. Select a region that supports Availability Zones before deployment; Central US is the known-good default because North Central US does not support the required zonal configuration. Do not add a subnet named `default`. Give each subnet one clear purpose, verify current service delegation and minimum-size requirements, and leave growth space.

## 🤔 Why Azure Container Apps?

You should still compare the options rather than accepting a service name without analysis.

| Option | Strength | Why it is not the baseline here |
| --- | --- | --- |
| Azure Container Apps | Managed revisions, internal ingress, KEDA-based scaling, managed platform operations | **Selected baseline** |
| App Service for Containers | Familiar web hosting and deployment slots | Multi-service internal networking and revision-based container operations are less natural for this target |
| AKS | Full Kubernetes APIs, extensibility, and scheduling control | The workload has no demonstrated need for Kubernetes control-plane access, CRDs, or custom operators |

Azure Container Apps is the best fit for this exercise because it meets the container, private ingress, scaling, and revision requirements without asking a small team to operate Kubernetes. Resilience comes from a zone-redundant environment, at least two application replicas, bounded autoscaling, and Azure Front Door Premium as the private global entry point. This gives the workshop a meaningful availability design without doubling every application resource.

## 🔒 Non-Negotiable Requirements

Your plan and implementation must:

- place both VMs in the primary database VNet and assign neither a public IP
- use Azure Bastion for browser-based RDP and SSH
- place SQL MI in its own delegated subnet in the peered secondary database VNet
- disable Azure SQL public network access and use Private Link and private DNS
- use one internal, zone-redundant workload-profile Container Apps environment in a dedicated application VNet
- expose the single application origin through Front Door Premium and Private Link
- run at least two placeholder-app replicas and use a bounded HTTP scaling rule
- use a Microsoft sample image on port `8080`; do not deploy the workshop application code
- use GitHub Actions OIDC, not a client secret
- scope the deployment identity to the lab resource groups
- use managed identities and deterministic, narrowly scoped role assignments
- store generated VM credentials in Key Vault and never print or commit them
- keep SQL MI in a separate manual workflow
- parameterize names, locations, CIDRs, SKUs, capacity, and required tags

## 🧪 Challenge 1: Explore Before You Plan

Continue in the same VSCode chat you were using. Use **Ask** mode to learn
what is already in the repository and to identify the evidence behind the
requirements.

```text
Explore this repository for Lab 04 without changing any files.

Identify:
- the Lab 04 requirements in infra/lab04/requirements.md
- the Azure resources implied by application configuration
- security, identity, networking, availability, operations, and cost constraints
- assumptions or conflicts that require human review

For each conclusion, cite the repository file that supports it. Separate observed
facts from recommendations. Do not create an implementation plan yet.
```

Review the inventory. Ask follow-up questions when a conclusion is unsupported
or a repository requirement has been missed. This step keeps
the plan grounded in evidence instead of accepting a plausible but generic Azure
design.

## 🧪 Challenge 2: Produce and Review the Plan

Open Copilot Chat in **Plan** mode and submit:

```text
Analyze this repository and plan the Azure foundation for Lab 04.

Use the repository inventory we just reviewed.

Treat the Required Final Architecture and Non-Negotiable Requirements in
infra/lab04/requirements.md as a minimum, not a complete design. For every
application setting that implies an Azure resource, provision that resource at a
lab-sized SKU. Report what you added, what you deliberately left out, and why.

Before proposing Bicep files:
1. Compare Azure Container Apps, App Service for Containers, and AKS.
2. Produce a CIDR and subnet table with no overlaps.
3. Produce an identity and least-privilege RBAC matrix.
4. Separate the base deployment from the optional SQL Managed Instance deployment.
5. Explain failure modes, recovery, regional routing, scaling limits, cost drivers,
   secure administration, and cleanup.
6. List assumptions and unresolved questions.

Plan only Bicep files under infra/lab04/student/. Use modules where they create clear
resource boundaries, parameterize environment-specific values, and keep secrets out
of source and parameter files. Do not create or modify files. Stop for review.
```

Do not approve the first response automatically. Reject a plan that:

- puts public IPs on the VMs
- enables Azure SQL public access
- uses one Container Apps environment for two regions
- calls two replicas “multi-region”
- grants Contributor at subscription scope
- uses an Azure client secret
- deploys SQL MI automatically with the base environment
- embeds credentials in parameters, outputs, logs, or repository files

The architecture is constrained, but these design decisions still require an
explicit rationale:

- module boundaries
- exact safe subnet sizes
- development VM and database SKUs
- maximum replica count and HTTP concurrency threshold
- naming convention and unique suffix strategy

Use focused follow-up prompts instead of asking Copilot to "make it better":

```text
Revise the plan with a decision record for every unresolved item. For each decision,
show the selected option, alternatives considered, evidence, tradeoffs, and the
condition that would cause us to revisit it. Do not implement anything.
```

```text
Review this plan as a skeptical Azure architect. Identify gaps against the Required
Final Architecture, Non-Negotiable Requirements, Azure Well-Architected pillars, and
the workshop architecture callout. Pay particular attention to network paths, DNS,
failure domains, recovery objectives, least privilege, secret handling, and bounded
scaling. Do not revise the plan until I approve the findings.
```

Resolve the findings and capture the approved plan before switching modes. Human
approval is the gate between planning and generation.

## 🧪 Challenge 3: Generate the Bicep

Switch to **Agent** mode:

```text
Implement the approved Lab 04 plan only under infra/lab04/student/.
Generate Bicep only. Do not deploy resources, run deployment scripts, modify workflows,
or edit infra/lab04/complete/.

Use current stable resource API versions, no committed secrets, Entra-only Azure SQL
authentication, internal Container Apps environments, bounded scaling, deterministic
role assignments, and parameter files with lab-sized defaults.

Follow the approved module boundaries and entry-point contracts. After generation,
build every Bicep entry point and show me the diff, validation output, and all
remaining warnings. Stop before making any unplanned correction.
```

Inspect the result:

```powershell
Get-ChildItem .\infra\lab04\student -Recurse
git diff -- .\infra\lab04\student
Get-ChildItem .\infra\lab04\student -Filter *.bicep -Recurse |
  ForEach-Object { az bicep build --file $_.FullName --stdout | Out-Null }
```

Building checks Bicep syntax, types, and compile-time rules. It does **not** prove
that resource names are available, quotas are sufficient, policies allow the
configuration, or deployment and runtime behavior will succeed.

Use the [Lab 04 requirements](https://github.com/Skillable-Events/caldova-retail/blob/main/infra/lab04/requirements.md)
(`infra/lab04/requirements.md` in your fork) as the implementation checklist.

## 🧪 Challenge 4: Run the Human Review

Ask Copilot for a review before asking it to fix anything:

```text
Review my generated files under infra/lab04/student/ against the approved plan
and the Required Final Architecture and Non-Negotiable Requirements in
infra/lab04/requirements.md.

Report findings first, ordered by severity. Cite the affected file and explain the
deployment or runtime consequence. Check Bicep correctness, dependency ordering,
network and private DNS paths, least-privilege RBAC, secret exposure, availability,
bounded scaling, parameterization, and deterministic naming. Do not edit files.
```

Investigate each finding, approve the corrections you agree with, and ask Copilot
to implement only those corrections. Rebuild all generated Bicep after each
approved review batch and inspect the diff again.

Finally, compare your approach with
[the complete implementation](https://github.com/Skillable-Events/caldova-retail/blob/main/infra/lab04/complete/README.md)
(`infra/lab04/complete/` in your fork). Differences
are discussion points, not automatic defects. Be prepared to explain:

- which requirements both implementations satisfy
- where module boundaries or parameter choices differ
- which design you would take to a formal architecture review
- what evidence is still missing before a production deployment

## 🏫 About the Preprovisioned Environment

Before the workshop, the instructor uses the tested Bicep implementation to
provision the shared Lab 04 foundation, including resource groups, Key Vault,
generated VM credentials, deployment identities, and scoped role assignments.

GitHub OIDC federation is repository-specific because each federated credential
includes the GitHub repository and environment in its subject. The instructor
or repository administrator completes that final binding for `lab06` and
`lab06-deploy` at the beginning of Lab 06. It authorizes application delivery
to the existing platform; it is not used to deploy your Lab 04 Bicep.

Participants do not run the full Lab 04 infrastructure bootstrap, deploy their
generated Bicep, trigger the Lab 04 infrastructure workflow, or clean up the
shared environment. Your local implementation is intentionally kept separate
from the environment used in later labs.

OIDC allows GitHub to exchange a short-lived job token for an Azure token, so no
Azure client secret is stored. The preprovisioned Lab 06 identity receives only
`AcrPush` on the registry, `Container Apps Contributor` on the retail app, and
Reader on the Front Door profile for endpoint discovery and smoke testing.

## 🐢 Predeployed SQL Managed Instance

The instructor deployment uses SQL MI by default and requests the Freemium
General Purpose v2 offer first. If the subscription or region cannot use the
free offer, the instructor can select the paid `Regular` pricing model without
an additional confirmation prompt.

Participants do not deploy Bicep. To allow only your current public IPv4:

```powershell
az login
.\assets\scripts\Enable-Lab04SqlMiPublicAccess.ps1 `
  -SubscriptionId '<subscription-id>'
```

The script asks before detecting your address, then creates or updates one
inbound NSG rule with a deterministic, privacy-safe name derived from your
signed-in Azure account and subscription. The rule is scoped to your `/32` on
TCP 3342, and multiple participants do not overwrite each other. Rerun it if
your public IP changes. Your instructor must grant Network Contributor on only
the SQL MI NSG. Connect to the endpoint reported by the script using Microsoft
Entra authentication. SQL authentication is disabled.

## ✅ Review Checklist

- [ ] Every generated Bicep file builds locally without errors.
- [ ] The implementation matches the approved plan or records an approved deviation.
- [ ] Every Azure setting the app reads (for example Key Vault, Application Insights, or Redis) is backed by a planned resource, or the gap is recorded with a reason.
- [ ] Front Door uses Private Link to reach one internal Container Apps origin.
- [ ] The placeholder has a minimum of two replicas and a bounded maximum.
- [ ] The Container Apps environment is internal and zone-redundant.
- [ ] Both VMs have no public IP and use Bastion for management.
- [ ] Azure SQL public network access is disabled and private DNS is linked correctly.
- [ ] SQL MI access is isolated from the base deployment and uses Microsoft Entra authentication.
- [ ] Database and application network paths are explicit, nonoverlapping, and justified.
- [ ] GitHub Actions uses OIDC and no Azure client secret exists.
- [ ] Role assignments use deterministic IDs and the narrowest practical scopes.
- [ ] No credential appears in source, workflows, parameters, logs, or outputs.
- [ ] Reliability, resiliency, security, operations, cost, and performance assumptions are documented for further review.
- [ ] Static validation is not presented as proof of deployment or production readiness.

## 📖 References

- [What is an Azure landing zone?](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Choose an Azure container service](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree)
- [Azure Container Apps networking](https://learn.microsoft.com/azure/container-apps/networking)
- [Azure Front Door with private Container Apps origins](https://learn.microsoft.com/azure/container-apps/front-door-custom-virtual-network-private-link)
- [Authenticate to Azure from GitHub Actions with OIDC](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect)
- [Managed identities for Azure resources](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview)
- [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview)
- [Azure SQL private endpoints](https://learn.microsoft.com/azure/azure-sql/database/private-endpoint-overview)
