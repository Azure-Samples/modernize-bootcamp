# 🔎 Lab 07: Assess a Multi-Repository Application with GitHub Copilot Modernization

Contoso Legacy Bank is not one project in one repository. Its customer portal, account service, statement API, document worker, and nightly batch process are separate .NET Framework applications that collaborate at runtime.

In this lab, you will use **GitHub Copilot modernization in Visual Studio Code** and the **GitHub Copilot Modernization CLI** to assess the five repositories as one application estate. You will compare interactive findings with repeatable CLI reports, reconcile the evidence, and create a dependency-aware modernization roadmap.

> [!IMPORTANT]
> This is an **assessment and planning lab**. Remain read-only while assessing the application. You may generate draft plans, but do not run `modernize plan execute`, `modernize upgrade`, or ask an agent to change application code.

## 🎯 Learning objectives

By the end of this lab, you will be able to:

- prepare a multi-repository workspace for application assessment
- distinguish repository-level findings from application-wide dependencies
- use GitHub Copilot in VS Code to investigate contracts and consumers across repositories
- run a repeatable, assessment-only scan with the Modernization CLI
- compare AI-generated findings with repository and build evidence
- prioritize modernization work across repository boundaries
- create bounded plans without starting implementation

## 📦 What you will produce

Save your results in a location provided by your instructor or in a local working document outside the application repositories. Your final handoff should contain:

1. the exact commit SHA assessed for the hub and each component repository
2. a finding register covering all five repositories
3. a comparison of the VS Code and CLI results
4. a contract and dependency summary
5. a prioritized, dependency-ordered modernization roadmap
6. bounded draft plans for the first modernization wave
7. assumptions, unknowns, and decisions that require human owners

Generated reports can contain source details and architectural information. Review and redact them before publishing or sharing them outside the workshop.

## 🏦 Application estate

The hub repository is [Skillable-Events/modernize_sample_demo](https://github.com/Skillable-Events/modernize_sample_demo). It contains orchestration, documentation, a multi-root VS Code workspace, and five application repositories pinned as Git submodules.

| Repository | Legacy technology | Responsibility | Example modernization direction |
| --- | --- | --- | --- |
| `contoso-legacy-bank-portal` | .NET Framework 4.8, WinForms, WCF client | Customer search, account views, transactions, and statement requests | Blazor and asynchronous service clients |
| `contoso-legacy-bank-accounts` | .NET Framework 4.8, WCF, EF6, SQL LocalDB | Customers, accounts, balances, and transactions | ASP.NET Core API, EF Core, and Azure SQL |
| `contoso-legacy-bank-statements` | ASP.NET Web API 2 | Statement orchestration and status | ASP.NET Core API with resilient clients |
| `contoso-legacy-bank-documents` | Console/Windows Service worker, file queue, PDFsharp | PDF statement generation | Modern .NET worker, managed messaging, and Blob Storage |
| `contoso-legacy-bank-batch` | Scheduled console app and CSV files | Nightly transaction import and reconciliation | Azure Functions or Azure Container Apps Jobs |

The hub is the system of record for application-wide architecture and sequencing. Each component repository remains the owner of its code and any future implementation work.

## 🧭 How the two assessment paths work together

You will use two complementary workflows:

| Workflow | Best use in this lab | Limitation to remember |
| --- | --- | --- |
| VS Code modernization assessment | Detailed, interactive findings for an individual project or repository | A repository-level result might not identify every external consumer |
| VS Code multi-root Copilot Chat | Trace contracts, consumers, data flow, and migration order across all five repositories | Results depend on attached context and must be verified against code |
| Modernization CLI | Repeatable per-repository and aggregated reports from one configuration | An aggregate report is evidence, not an approved architecture |

Neither output is automatically authoritative. Repository code, build results, tests, runtime behavior, and owner decisions remain the evidence used to accept or reject a recommendation.

---

## 1️⃣ Prepare the workstation

This lab assumes a Skillable Windows workstation. Git, GitHub CLI, VS Code, GitHub Copilot, Visual Studio build tools, and the modernization tools should already be installed.

### 1. Open PowerShell

Use a regular PowerShell terminal. Do not run these commands from inside another application repository.

### 2. Verify the command-line tools

```powershell
git --version
gh --version
code --version
modernize --help
```

Each command should print version or help information.

If `modernize` is not recognized, install the current Windows package:

```powershell
winget install GitHub.Copilot.modernization.agent
```

After installation, close PowerShell, open a new PowerShell terminal, and run:

```powershell
modernize --help
```

> [!NOTE]
> The installer adds `modernize` to your user `PATH`. An already-open terminal does not see that change.

### 3. Authenticate to GitHub

Check whether GitHub CLI is already authenticated:

```powershell
gh auth status
```

If it is not authenticated, run:

```powershell
gh auth login
```

Choose:

1. **GitHub.com**
2. **HTTPS**
3. **Login with a web browser**

Complete the browser sign-in, then verify again:

```powershell
gh auth status
```

The signed-in account must have GitHub Copilot access and read access to the hub and all five component repositories.

### 4. Verify VS Code extensions

Open VS Code, select **Extensions** in the Activity Bar, and confirm these extensions are installed and enabled:

- **GitHub Copilot**
- **GitHub Copilot Chat**
- **GitHub Copilot modernization**

If an extension is missing, search for its exact name and install the verified publisher's extension. Reload VS Code if prompted, then sign in to GitHub when requested.

---

## 2️⃣ Clone and initialize the application estate

### 1. Clone the hub and all submodules

In PowerShell, choose a working folder and run:

```powershell
git clone --recurse-submodules https://github.com/Skillable-Events/modernize_sample_demo.git
Set-Location .\modernize_sample_demo
```

If you already cloned the hub without its submodules, run this instead from the hub root:

```powershell
git submodule update --init --recursive
```

### 2. Initialize the demo

```powershell
.\scripts\Initialize-Demo.ps1
```

The script prepares the local integration folders and data used by the application estate.

### 3. Check prerequisites

```powershell
.\scripts\Test-Prerequisites.ps1
```

The check covers:

- Visual Studio MSBuild
- .NET Framework 4.8 targeting pack
- IIS Express
- SQL Server Express LocalDB
- Git
- initialized submodules

Do not treat missing build prerequisites as modernization findings. Fix the workstation or record the lab limitation before assessing the code.

### 4. Establish a build baseline

```powershell
.\scripts\Build-All.ps1
```

An assessment from a broken or incomplete baseline can confuse environmental failures with application modernization work. Record the build result, including any known pre-existing failure.

Running the complete application is not required for this assessment lab. If your instructor asks you to demonstrate it, use the hub scripts:

```powershell
.\scripts\Start-Demo.ps1
.\scripts\Invoke-BatchSample.ps1
.\scripts\Stop-Demo.ps1
```

### 5. Record the assessed revisions

Record the hub SHA:

```powershell
git rev-parse HEAD
```

Record each pinned component SHA:

```powershell
git submodule status
```

Keep this output with your final handoff. A branch name such as `main` can move; a commit SHA identifies the code that produced the assessment.

---

## 3️⃣ Open the multi-repository workspace

From the hub root, run:

```powershell
code .\contoso-legacy-bank-multi-repo.code-workspace
```

The VS Code Explorer should show five named application roots under `apps`:

- Portal
- Accounts
- Statements
- Documents
- Batch

It may also show the hub for shared documentation and orchestration.

Before starting an assessment:

1. wait for VS Code workspace indexing to settle
2. trust the workspace only if you recognize the repository
3. confirm all five roots contain source files
4. review `.github\copilot-instructions.md` in the hub and each component repository
5. keep the Source Control view clean so generated or accidental changes are obvious

> [!IMPORTANT]
> The folders under `apps\` are independent Git repositories. Do not treat them as ordinary hub files. Future code changes would be committed in the owning component repository first, followed by a separate hub submodule-pointer update.

---

## 4️⃣ Assess each repository in VS Code

The modernization extension produces the most useful project-level detail when each application is assessed deliberately. Repeat this workflow for **Portal, Accounts, Statements, Documents, and Batch**.

The extension UI can evolve. Labels might vary slightly, but the assessment choices and review goals remain the same.

### 1. Start an assessment

1. Select the **GitHub Copilot modernization** icon in the Activity Bar.
2. Select **Start Assessment**.
3. Select the project or solution from one component repository.
4. Choose **Recommended Assessment** when offered.
5. Choose **Cloud Readiness** as the target.
6. Keep the run in assessment mode. Do not choose an upgrade or execution action.

If the extension cannot distinguish projects in the multi-root workspace, open the relevant component in a separate VS Code window:

```powershell
code .\apps\contoso-legacy-bank-accounts
```

Replace the folder name and repeat for the other repositories.

### 2. Review the result

For each repository, inspect:

- detected framework, project type, and dependencies
- mandatory, potential, and optional findings
- affected files and symbols
- why the finding matters for the proposed target
- remediation guidance
- effort estimate and assumptions
- test or runtime evidence needed before accepting the recommendation

Do not select **Create Plan** yet. First complete all five assessments and the application-wide analysis.

### 3. Build the finding register

Capture findings in this format:

| ID | Repository | Finding | Priority | File or symbol evidence | Consumer or dependency impact | Proposed direction | Confidence / unknowns |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VS-01 | Accounts |  |  |  |  |  |  |
| VS-02 | Statements |  |  |  |  |  |  |

At minimum, investigate these areas:

| Repository | Assessment focus |
| --- | --- |
| Portal | WinForms UI coupling, synchronous calls, WCF client configuration, validation, roles, and error states |
| Accounts | WCF contracts/bindings/faults, EF6 behavior, LocalDB assumptions, transactions, and all consumers |
| Statements | Web API 2 routes and payloads, WCF client use, status behavior, timeouts, and failure handling |
| Documents | File-queue claim/replay behavior, PDF output, local paths, service hosting, and failed jobs |
| Batch | CSV schema, duplicate handling, reconciliation, scheduling, local paths, and partial failures |
| All repositories | Configuration, secrets, logging, health, telemetry, package support, build/test coverage, and CI |

### 4. Check that assessment did not change source

From the hub root:

```powershell
git status --short
git submodule foreach --recursive 'git status --short'
```

Assessment dashboards or reports might create ignored local artifacts. Application source should remain unchanged.

---

## 5️⃣ Analyze the application across repositories in VS Code

Repository assessments do not automatically prove how a contract is consumed elsewhere. Use the multi-root workspace and Copilot Chat to investigate the application as a connected system.

### 1. Open Copilot Chat

Return to `contoso-legacy-bank-multi-repo.code-workspace`, open **Copilot Chat**, and use **Ask** or **Agent** mode in a read-only manner. Start with `#codebase` so VS Code searches the indexed workspace.

### 2. Submit the application-wide assessment prompt

```plaintext
#codebase Analyze all five Contoso Legacy Bank application repositories as one
system. Remain read-only and do not edit files, create branches, or implement
changes.

Inventory each executable, project, framework, data store, file store, endpoint,
startup dependency, and external configuration. Trace every runtime contract
from producer to consumer, including WCF operations and faults, HTTP routes and
payloads, JSON, CSV, LocalDB, file-queue messages, and generated PDF output.

For every conclusion, cite the repository, file, and symbol that support it.
Separate observed facts from inferred conclusions, assumptions, and unknowns.
Identify unsupported dependencies, cloud-readiness blockers, test gaps,
coexistence requirements, rollback needs, and cross-repository sequencing.

Recommend a dependency-ordered modernization roadmap using supported modern
.NET and appropriate Azure services. Preserve observable behavior and do not
assume all repositories can change in one release. End with independently
implementable repository work packages and human decision gates.
```

### 3. Challenge the output

Ask focused follow-ups instead of accepting the first response:

```plaintext
Show the code evidence for every producer and consumer in the WCF dependency
chain. Which consumers would break if the account service changed first?
```

```plaintext
Trace statement generation from the portal request through the account service,
statement API, file queue, document worker, and PDF result. Mark every contract
that needs a compatibility or coexistence strategy.
```

```plaintext
Which recommendations are directly supported by code, which are inferred, and
which require a product owner, security owner, data owner, or operations owner?
```

### 4. Capture the contract matrix

| Producer | Consumer | Contract or data | Evidence | Current failure behavior | Modernization/coexistence concern |
| --- | --- | --- | --- | --- | --- |
| Accounts | Portal | WCF operations and faults |  |  |  |
| Accounts | Statements | WCF operations and DTOs |  |  |  |
| Statements | Portal | HTTP routes and payloads |  |  |  |
| Statements | Documents | File-queue message |  |  |  |
| Batch | Accounts/data store | CSV and import semantics |  |  |  |

The output should make dependencies visible, not merely list technologies.

---

## 6️⃣ Run the multi-repository Modernization CLI assessment

The hub contains `.github\modernize\repos.json`. It lists the five application repositories and groups them as one logical application named `contoso-legacy-bank`. The hub itself is excluded because it contains orchestration and documentation rather than an application project.

### 1. Confirm authentication and CLI availability

From the hub root:

```powershell
gh auth status
modernize --help
```

### 2. Inspect the repository configuration

```powershell
Get-Content .\.github\modernize\repos.json
```

Confirm that it lists:

- `contoso-legacy-bank-portal`
- `contoso-legacy-bank-accounts`
- `contoso-legacy-bank-statements`
- `contoso-legacy-bank-documents`
- `contoso-legacy-bank-batch`

### 3. Run the supplied assessment-only wrapper

```powershell
.\scripts\Invoke-ModernizeAssessment.ps1
```

The wrapper intentionally runs only `modernize assess`. It writes Markdown assessment output beneath:

```text
artifacts\modernize-assessment
```

The script is equivalent to:

```powershell
modernize assess `
  --source .github\modernize\repos.json `
  --output-path artifacts\modernize-assessment `
  --format markdown `
  --delegate local
```

The repository config allows the CLI to produce per-repository findings and an application-level aggregate without requiring you to type five URLs.

> [!WARNING]
> Do not substitute `modernize upgrade` and do not run `modernize plan execute`. Those commands can change source. This lab ends at reviewed assessment and draft planning.

### 4. Review generated files

List the output:

```powershell
Get-ChildItem .\artifacts\modernize-assessment -Recurse -File |
  Select-Object FullName, Length, LastWriteTime
```

Open the generated Markdown reports in VS Code:

```powershell
code .\artifacts\modernize-assessment
```

Verify:

- all five repositories have results
- the aggregate groups them as one application
- findings include file or project evidence rather than generic advice
- cross-repository risks are not hidden by repository-level summaries
- failed, skipped, or incomplete scans are clearly identified
- assessed revisions match the SHAs recorded earlier

Do not publish raw reports until they have been reviewed for source details, internal URLs, secrets, credentials, personal data, and unsupported claims.

### 5. Optional: run the interactive CLI

The same CLI also provides a text user interface:

```powershell
modernize
```

In the menu:

1. choose **Assess**
2. choose **From a config file**
3. select `.github\modernize\repos.json`
4. keep all five repositories selected
5. select the .NET **Upgrade** and **Cloud Readiness** assessment domains
6. choose **Full analysis** when codebase insights are offered
7. choose **Assess locally**
8. select an output directory
9. review the results, then return to the main menu

Do not continue into plan execution or upgrade.

---

## 7️⃣ Compare and reconcile the results

The goal is not to decide which tool "won." Determine which findings are supported by evidence and which gaps require more investigation.

### 1. Compare coverage

| Question | VS Code result | CLI result | Evidence checked | Reconciled conclusion |
| --- | --- | --- | --- | --- |
| Were all five repositories analyzed? |  |  |  |  |
| Were frameworks and packages detected correctly? |  |  |  |  |
| Were WCF producers and consumers connected? |  |  |  |  |
| Were HTTP, CSV, file-queue, and PDF contracts identified? |  |  |  |  |
| Were data and LocalDB assumptions identified? |  |  |  |  |
| Were test and observability gaps identified? |  |  |  |  |
| Were findings supported by files and symbols? |  |  |  |  |
| Did the result separate facts, assumptions, and unknowns? |  |  |  |  |
| Did it propose safe coexistence and rollback? |  |  |  |  |
| Did it aggregate risks at application level? |  |  |  |  |

### 2. Reconcile disagreements

For every important disagreement:

1. locate the relevant source, configuration, test, or build output
2. identify whether one tool lacked repository or workspace context
3. classify the conclusion as **confirmed**, **rejected**, or **unknown**
4. record the evidence and confidence
5. assign unresolved decisions to a human owner

Use this register:

| ID | Topic | VS Code conclusion | CLI conclusion | Verified evidence | Decision | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| RC-01 |  |  |  |  |  |  |

### 3. Identify assessment gaps

A complete report can still be based on incomplete evidence. Look for:

- untested runtime failure paths
- missing performance and volume data
- unknown recovery objectives
- undocumented identity and authorization behavior
- unclear data ownership or retention
- missing downstream consumers
- secrets or environment dependencies not represented in source
- recommendations that assume a target Azure service without business constraints

---

## 8️⃣ Prioritize the modernization portfolio

Score work by dependency and risk, not only by how old a framework is.

### 1. Build the prioritization matrix

Use **High**, **Medium**, or **Low** consistently:

| Repository/capability | Business impact | Technical risk | Dependency criticality | Test readiness | Estimated effort | Coexistence need | Recommended wave |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Account contracts and data |  |  |  |  |  |  |  |
| Statement orchestration |  |  |  |  |  |  |  |
| Document generation |  |  |  |  |  |  |  |
| Batch reconciliation |  |  |  |  |  |  |  |
| Customer portal |  |  |  |  |  |  |  |

### 2. Propose modernization waves

A defensible starting sequence is:

1. **Baseline and contract preservation:** Record behavior, freeze public contracts, close characterization-test gaps, and agree on target runtime and hosting decisions.
2. **Account service and data boundary:** Address the WCF/EF6/LocalDB dependency while preserving a compatibility path for Portal and Statements.
3. **Statement service:** Move Web API 2 and replace its account-service client without breaking request/status behavior.
4. **Documents and Batch:** Modernize worker hosting, file-queue semantics, PDF storage, scheduling, idempotency, and reconciliation.
5. **Portal:** Modernize the UI after stable service contracts exist.
6. **Parity, cutover, and retirement decision:** Validate consumers, behavior, security, operations, rollback, and data before retiring legacy endpoints.

Change the sequence only when your evidence supports the decision. For example, missing behavior tests might make characterization work the first task in every repository.

### 3. Define human approval gates

Record who must approve:

- public contract and intentional behavior changes
- target .NET versions and support policy
- Azure service and network architecture
- identity, authorization, and secret handling
- data migration and transaction semantics
- availability, recovery, and rollback objectives
- cost and operational ownership
- legacy endpoint retirement

An AI-generated recommendation does not authorize any of these decisions.

---

## 9️⃣ Create bounded draft plans

Create plans only after the assessment findings have been reconciled. Keep each plan limited to one repository and one modernization slice.

### 1. Locate assessment JSON files

```powershell
$assessmentFiles = @(
  Get-ChildItem .\artifacts\modernize-assessment `
    -Recurse `
    -Filter *.json `
    -File
)

$assessmentFiles | Select-Object FullName
```

Identify the assessment file that contains the findings for the repository you are planning. Do not guess from the filename; open it and verify the repository identity and findings.

### 2. Create a plan from reviewed evidence

The following example creates a plan for the Accounts repository. Replace the placeholder with the verified assessment JSON path:

```powershell
$accountsAssessment = Read-Host 'Enter the verified Accounts assessment JSON path'
$planPrompt = @'
Modernize the account service from .NET Framework 4.8, WCF, EF6, and LocalDB
to supported modern .NET, versioned ASP.NET Core APIs, EF Core, and Azure SQL.
Preserve current operations, faults, transaction behavior, and consumers
through an explicit coexistence strategy. Plan only; do not execute.
'@

modernize plan create $planPrompt `
  --source .\apps\contoso-legacy-bank-accounts `
  --assess-file-path $accountsAssessment `
  --plan-name accounts-foundation `
  --language dotnet
```

Repeat only for approved first-wave work. Use a unique plan name and the matching repository assessment file.

### 3. Review the generated plan

Review both:

- `.github\modernize\<plan-name>\plan.md`
- `.github\modernize\<plan-name>\tasks.json`

Confirm the plan:

- cites assessment evidence
- names affected contracts and consumers
- preserves behavior or explicitly versions an intentional change
- includes tests and measurable success criteria
- supports coexistence and rollback
- has repository-bounded ownership
- does not combine unrelated repositories into one implementation task
- stops before cutover or legacy retirement without owner approval

You may edit a draft plan for review. **Do not run it in this lab.**

> [!CAUTION]
> `modernize plan execute` applies changes and can create commits. `modernize upgrade` performs an end-to-end modernization workflow. Neither command belongs in this assessment lab.

---

## 🔟 Final handoff

Your final handoff should be understandable to an architect or repository owner who did not attend the lab.

### Assessment summary

| Item | Result |
| --- | --- |
| Hub commit SHA |  |
| Component commit SHAs |  |
| Baseline build |  |
| VS Code assessments completed |  |
| CLI repositories completed |  |
| Confirmed high-priority findings |  |
| Rejected or unsupported findings |  |
| Open unknowns |  |

### Roadmap summary

| Wave | Outcome | Repositories | Prerequisites | Exit evidence | Human approver |
| --- | --- | --- | --- | --- | --- |
| 0 |  |  |  |  |  |
| 1 |  |  |  |  |  |

### Work-package summary

| Work package | Owning repository | Assessment evidence | Dependencies | Success criteria | Rollback/coexistence |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |

### Completion checklist

- [ ] The hub and all five component SHAs are recorded.
- [ ] The prerequisite and baseline results are recorded.
- [ ] Portal, Accounts, Statements, Documents, and Batch were assessed.
- [ ] The CLI generated per-repository and aggregate output.
- [ ] Important findings cite repository evidence.
- [ ] VS Code and CLI disagreements were reconciled.
- [ ] Facts, assumptions, and unknowns are separated.
- [ ] Contracts and consumers are represented in the roadmap.
- [ ] Modernization waves are dependency ordered.
- [ ] First-wave plans are bounded and reviewable.
- [ ] No plan was executed and no application source was changed.
- [ ] Reports were reviewed and redacted before sharing.

---

## 🛠️ Troubleshooting

### A component folder is empty or missing

From the hub root:

```powershell
git submodule update --init --recursive
git submodule status
```

Every component should show a commit SHA. A leading `-` in `git submodule status` means the submodule is not initialized.

### The prerequisite script reports missing .NET Framework tools

This estate intentionally uses .NET Framework 4.8. The baseline requires:

- Visual Studio 2022 or Build Tools
- .NET desktop build tools
- .NET Framework 4.8 targeting pack
- ASP.NET and web development build tools
- IIS Express
- SQL Server Express LocalDB

Use the Skillable-provided installation. If a required component is unavailable, record the environmental limitation and do not report it as an application finding.

### `modernize` is not recognized

Install it:

```powershell
winget install GitHub.Copilot.modernization.agent
```

Close all PowerShell terminals, open a new one, and run:

```powershell
modernize --help
```

### GitHub authentication or entitlement fails

```powershell
gh auth status
gh auth login
```

Confirm the browser and VS Code use the same intended GitHub account and that the account has Copilot access plus access to all six repositories.

### VS Code does not search all repositories

1. reopen `contoso-legacy-bank-multi-repo.code-workspace`
2. confirm every root appears in Explorer
3. wait for indexing to finish
4. start the prompt with `#codebase`
5. attach specific files or folders when asking about a contract
6. split broad questions into a producer trace and a consumer trace

### The modernization extension does not offer the expected project

Open that component repository in its own VS Code window:

```powershell
$componentFolder = Read-Host 'Enter the component folder name'
code (Join-Path '.\apps' $componentFolder)
```

Then start the assessment again and select its solution or project.

### The CLI assessment takes a long time

Full analysis across five repositories is expected to take longer than a single-project scan. Keep the terminal open. If the command fails:

1. read the final error rather than immediately rerunning
2. verify authentication and repository access
3. check available disk space
4. inspect the output directory for partial or failed reports
5. move the failed output aside before a clean rerun so old and new results are not mixed

Do not describe partial output as a complete portfolio assessment.

### One repository was skipped or failed

Confirm its URL and branch in:

```powershell
Get-Content .\.github\modernize\repos.json
```

Verify access:

```powershell
$repositoryName = Read-Host 'Enter the repository name'
gh repo view "Skillable-Events/$repositoryName"
```

Record the repository as incomplete until a successful result exists. Do not infer its findings from another repository.

### Assessment created unexpected changes

Inspect the hub and each component:

```powershell
git status --short
git submodule foreach --recursive 'git status --short'
```

Do not discard changes until you know who created them. If they came from an accidental plan or upgrade action, stop and ask the instructor before continuing.

## 📚 Optional references

Everything required for the lab is documented above. These references are useful after the workshop because product commands and interfaces can evolve:

- [GitHub Copilot modernization documentation](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/)
- [Modernization agent CLI commands](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/modernization-agent/cli-commands)
- [GitHub Copilot Modernization CLI repository](https://github.com/microsoft/modernize-cli)
- [VS Code multi-root workspaces](https://code.visualstudio.com/docs/editing/workspaces/multi-root-workspaces)
- [Using context in VS Code Chat](https://code.visualstudio.com/docs/copilot/chat/copilot-chat-context)
