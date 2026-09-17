# 📊 Lab 07: Add Azure Application Insights

> 🎓 **Short module** — Lab 08 builds on the telemetry you set up here, so do this one first if you plan to continue.

The storefront is running in Azure Container Apps. It works — and you have almost no idea what it's doing. Locally you had a debugger and a browser dev tools tab. In Azure you have a container log stream, which is unstructured text with no request timings, no correlation between a page and the query behind it, and no history beyond the retention on the log stream.

In this module you'll wire the app to [Azure Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) so its behavior is durable, queryable, and correlated — for the app your customers are actually using.

This module takes approximately **30 minutes**.

## 📋 What You'll Do

- 📡 Add the Azure Monitor OpenTelemetry distro to the storefront
- 🏗️ Add Application Insights to the Container Apps foundation generated in Lab 04
- 🔌 Pass the connection string in as configuration rather than code
- 🗺️ Read the Application Map, Live Metrics, transaction details, and failures
- 🔎 Prove — or disprove — the scale-out concerns raised back in Lab 03
- 💰 Control telemetry cost with sampling, daily caps, and retention

## 🧭 Where This Fits

Lab 04 provisioned the resilient Azure Container Apps foundation, Lab 05 prepared the managed data target, and Lab 06 replaced the placeholder through CI/CD. This module proves you can *operate* that workload — the observability conversation an infrastructure architect gets asked about on day two of any migration, usually right after the first incident.

> ‼️ **IMPORTANT**
>
> The starting point for this module is the **Lab 04 platform plus the Lab 05 data target**, with the modernized storefront image deployed by Lab 06.
>
> Do this module before Lab 08. The telemetry you wire up here is what you will use to watch the AI assistant's latency and failures once you add it.

## ✅ Prerequisites

Before you begin, make sure you have:

- an **Azure subscription** with permission to create resources — this module deploys to Azure, there's no local-only path
- the **Azure CLI**, signed in with `az login`
- Visual Studio Code with the **GitHub Copilot** extension, for the infrastructure change
- the Lab 04 Container Apps platform and its Bicep or your participant IaC
- the Lab 05 managed database target
- the modernized storefront image deployed in place of the Lab 04 placeholder

> 💡 If your subscription isn't ready, you can still complete Step 1 and point the app at an **existing** Application Insights resource by setting `APPLICATIONINSIGHTS_CONNECTION_STRING` in user secrets — for example, one your instructor shares with the room.

## 📚 Instructions

### What instrumentation do you actually have?

None. This is worth being blunt about, because it is the normal situation for a migrated app and not the one most tutorials assume.

A greenfield .NET app scaffolded today comes with OpenTelemetry wired up from the first commit. The Caldova storefront came from .NET Framework 4.8 by way of an upgrade agent. It emits `ILogger` output and nothing else — no traces, no metrics, no correlation IDs. There is no existing exporter to point somewhere new.

The **Azure Monitor OpenTelemetry distro** closes that gap in one call. `UseAzureMonitor()` configures OpenTelemetry and turns on automatic instrumentation for incoming ASP.NET Core requests, outbound `HttpClient` calls, and SQL client calls — which covers essentially everything this app does. You are not annotating methods or rewriting logging statements.

### Step 1: Add the package and turn on the exporter

1. Add the package to the storefront project:

    ```powershell
    dotnet add <path-to-storefront-project> package Azure.Monitor.OpenTelemetry.AspNetCore
    ```

1. Register the exporter in `Program.cs`, guarded by the connection string:

    ```csharp
    using Azure.Monitor.OpenTelemetry.AspNetCore;

    // Exports only when the hosting platform supplies a connection string, so local runs are unaffected.
    if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
    {
        builder.Services.AddOpenTelemetry().UseAzureMonitor();
    }
    ```

1. Build the project.

That is the entire code change: one package and four lines.

> 💡 **Why the guard**
>
> Same reasoning as the AI configuration in Lab 08. A developer with no Azure access should still be able to clone, build, and run the storefront. Telemetry that hard-fails the app when its backend is missing is worse than no telemetry.

> ‼️ **If the build fails with NU1605**
>
> A package downgrade error such as `NU1605: Detected package downgrade: OpenTelemetry.Extensions.Hosting` means the Azure Monitor distro depends on newer `OpenTelemetry.*` packages than something else in your solution has pinned. Update **every** `OpenTelemetry.*` package to the latest version rather than pinning the distro back. This is a very common real-world upgrade snag and worth pausing on — it is the same transitive-dependency conflict class you met during the framework upgrade.

> 💡 **Name the app**
>
> Telemetry is grouped by *cloud role name*, which defaults to the assembly name. If that isn't a name your operations team would recognize, set the `OTEL_SERVICE_NAME` environment variable in the container app — for example `caldova-storefront`. It costs nothing now and saves confusion the moment a second app reports to the same resource.

### Step 2: Add the resources to your infrastructure

Lab 04 produced the platform Bicep or your participant IaC, so this is an infrastructure change, not a portal click-through. Ask Copilot to extend what you already have:

```plaintext
Extend the infrastructure in this repo to add Azure Monitor telemetry for the storefront.

- Add a workspace-based Application Insights component in the same resource group and region as the app.
- If the Container Apps environment already has a Log Analytics workspace, reuse it rather than creating a second one.
- Pass the Application Insights connection string to the storefront container app as the APPLICATIONINSIGHTS_CONNECTION_STRING environment variable, using a secret reference rather than a literal value in the template.
- Set workspace retention to 30 days and add a daily ingestion cap.
- Do not change the app's ingress, scaling, or managed identity configuration.

Show me the diff before applying anything.
```

Review the diff, especially the second bullet. Creating a second Log Analytics workspace next to the one your Container Apps environment already uses is the most common mistake here, and you pay for both.

> 🔐 **Is the connection string a secret?**
>
> It contains an instrumentation key, which grants *write* access to your telemetry — not read access to it. It will not leak your data, but anyone holding it can pollute your telemetry and your bill. Treat it as a secret, keep it out of source, and reference it the same way you reference the database connection string.

### Step 3: Redeploy and generate traffic

1. Redeploy using the Lab 04 workflow.
1. Open the storefront URL and use it like a customer would: browse the catalog, search, open a product, add something to the cart, sign in with one of the [demo accounts](../00-Setup/Readme.md#-demo-accounts).
1. Give it two or three minutes. First ingestion is not instant, and an empty blade usually means "too early", not "broken".

### Step 4: Read your telemetry

In the [Azure Portal](https://portal.azure.com), open the resource group and select the **Application Insights** resource.

1. **Investigate > Application map.**

   With one app this is a smaller picture than a microservices demo, and that is fine — the edge that matters is the one from the storefront to its database, with average latency and error rate on it. That single edge is what settles the "is it the app or is it the database" argument, which is the argument you will actually be in. Nothing here was configured by hand; it is inferred from the traces the distro started emitting in Step 1.

1. **Investigate > Live metrics.**

   Refresh the storefront a few times and watch request rate, duration, and dependency calls update within a second or two. This is the blade to have open during a deployment or an incident.

1. **Investigate > Transaction search**, then open any request to the storefront.

   The end-to-end view shows the waterfall for one user request: the incoming page request, the EF Core SQL calls underneath it, and the timing of each. Compare a catalog page against a search — any caching introduced during the data modernization work in Module 04 should be visible in the difference.

1. **Investigate > Failures.**

   Exceptions are grouped by type and operation rather than scattered through a log stream. If your app is healthy there will be nothing here, which is itself worth showing a customer.

#### The scale-out question, answered with data

Module 03 flagged two problems that only appear when more than one instance is running: cart state held in process, and Data Protection keys written locally. Lab 04 configured at least two replicas, so those conditions now exist. Go and look:

```kusto
requests
| where timestamp > ago(1h)
| summarize requests = count(), avgDuration = avg(duration) by cloud_RoleInstance
```

More than one `cloud_RoleInstance` means traffic really is spread across replicas. If your fix for session state didn't land, this is where it shows up — sign-in exceptions or cart-related errors clustered on one instance rather than spread evenly.

That progression is the point of this module. In Module 03 the scale-out problem was a claim in a document. Here it is a query you can run in front of a customer.

### Step 5: Keep the bill under control

Application Insights bills on **data ingested**, so telemetry volume is a real cost lever on a busy app. Three things worth knowing before you recommend this to a customer:

- **Sampling is on by default.** The Azure Monitor distro applies rate-limited sampling. Tune it with `UseAzureMonitor(options => options.SamplingRatio = 0.5f)` when volume becomes a problem — and understand that sampling drops whole traces, not individual spans, so what's left is still coherent.
- **Set a daily cap.** On the Application Insights resource, go to **Configure > Usage and estimated costs > Daily cap** for a hard ceiling on ingestion. This is what protects you from a runaway logging loop becoming a surprise invoice.
- **Tune retention.** The default is 90 days. Shorter retention on non-production environments is an easy saving that nobody misses.

### Cleaning up resources

> ‼️ **Not yet, if you are continuing.** Lab 08 adds an AI assistant to this deployed app and reads its telemetry here. Only clean up when you are finished with both.

When you are done, delete the resource group you deployed to:

```powershell
az group delete --name <your-resource-group> --yes --no-wait
```

Confirm the group name first. Deleting a resource group removes everything in it, and there is no undo.

## ✅ Verification

By the end of this section, you should have:

- 🔹 Added the Azure Monitor OpenTelemetry distro to an app that previously emitted no telemetry
- 🔹 Added Application Insights to your Lab 04 infrastructure rather than clicking it into existence
- 🔹 Passed the connection string in as a secret reference, with the app still running locally without it
- 🔹 Read the Application Map, Live Metrics, an end-to-end transaction, and the Failures blade
- 🔹 Confirmed with a KQL query that the app is serving traffic from more than one replica
- 🔹 Understood how sampling, daily caps, and retention control cost

## 🚀 Going further

Topics worth exploring on your own — each is a natural next conversation with a customer:

- 📈 [Add custom metrics and traces](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify) with your own `ActivitySource` and `Meter`
- 🔍 [Query telemetry with KQL](https://learn.microsoft.com/azure/azure-monitor/logs/log-query-overview) across the `requests`, `dependencies`, `traces`, and `exceptions` tables
- 🚨 [Create alert rules](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-create-metric-alert-rule) on failure rate or response time
- 🧪 [Set up availability tests](https://learn.microsoft.com/azure/azure-monitor/app/availability-overview) to catch outages before your users do
- 📊 [Build workbooks and dashboards](https://learn.microsoft.com/azure/azure-monitor/visualize/workbooks-overview) for your operations team

---
[← Previous: Deploy Code with GitHub Actions](../06-deploy-code-with-github-actions/README.md) | [Next: Add AI Capabilities →](../08-add-ai-capabilities/README.md)
