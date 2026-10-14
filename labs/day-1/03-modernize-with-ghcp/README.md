# ☁️ Lab 03: Prepare the App Code for Azure

Module 2 moved the storefront onto .NET 10. To do that, the upgrade also had to rewrite how the app starts up and where it keeps its settings (now in `appsettings.json`). What it did not do is change the app's code to work with **Azure services**, such as Key Vault for secrets or Redis for shopping carts.

> 🎯 **This module: prepare the app's code for Azure.** You work on the **application code** only: rebuild the pages with Blazor, then close the code gaps that would stop the app working well with Azure services. Nothing is created in Azure and nothing is deployed. By the end, the app's code is *ready to use* Azure services, but the app is not running in Azure yet. Module 4 designs the Azure environment, and Module 6 deploys the app into it.

You work in **GitHub Copilot Chat** for the whole module: first with the **Upgrade** agent to convert the pages to Blazor, then with the GitHub Copilot modernization extension's **Migrate to Azure** option to find and fix the code changes the app needs before it can work with Azure services.

> 🧭 New to GitHub Copilot Chat? [Copilot Essentials](https://github.com/Azure-Samples/modernize-bootcamp/blob/main/docs/copilot-essentials.md) is a short reference on modes, models, context, cost, and course-correcting.

## 🛠️ Setup: Load the Upgraded .NET 10 Repository

In Module 2, you observed how GitHub Copilot Modernization assesses and begins an upgrade. Because this full agentic framework upgrade may take an hour, we pick up this module using a prepared copy of the storefront that is already upgraded to **.NET 10**.

Follow these steps to fork, clone, and configure the .NET 10 repository (like you did in the previous module):

1. In Microsoft Edge, open this link: +++https://github.com/Skillable-Events/caldova-retail-dotnet10+++. (Sign in with your lab credentials if prompted).
2. Select **Fork**, then **Create fork** with the defaults left alone.
3. In your new fork, select **Code**, then copy the **HTTPS** URL.
4. Open PowerShell from your applications and run these commands from the default location (`C:\Users\Admin`), replacing `<your-fork-url>` with the URL you copied:

   ```powershell
   git clone <your-fork-url>
   cd caldova-retail-dotnet10
   code .
   ```

5. Check for a notification in the banner at the top of VS Code. If the folder opens in **Restricted Mode**, select **Manage**, then **Trust**. Once VS Code shows **In a Trusted Folder**, close that tab.

   ![Restricted Mode banner](./images/restricted-mode-banner.png)
6. Open `src\eShopLite.StoreFx\appsettings.json` and replace the placeholder password in the `StoreDbContext` connection string with the **W11-Workstation** password from the **Resources** tab of your lab instructions (+++Pa$$w0rd+++). Leave the server, database, and user as they are.
7. Ask Copilot Chat to **Run the app** (and approve any tool call commands), then verify the product catalog loads in your browser before continuing.

## 📋 What you'll do

- 🚀 Rebuild the storefront's pages with Blazor components
- ☁️ Ask what the app's code needs to work with Azure services, and fix what comes back

## 1️⃣ Convert to Blazor pages

Right now, the storefront's pages are built with **ASP.NET MVC**. Each page is a *view* (an HTML template with blanks), and a separate *controller* handles each request, gets the data, and fills in the template. In this step you move the pages to **Blazor**, Microsoft's newer way to build web pages in .NET. With Blazor, each page is a *component*: a single file that holds both the page's layout and its code, built from reusable pieces such as a product card or the cart. The app still runs on .NET 10; only the way its pages are built changes.

Unlike Module 2, this step does change the pages themselves. Copilot will rebuild each page as a Blazor component. Because the pages are being rebuilt anyway, this is also a good moment to give the store a more modern look, so the prompt below asks for that too.

Select the **Upgrade** agent from the agent picker in Copilot Chat, then use the following prompt to guide Copilot:

![Select the Upgrade agent from the Copilot Chat agent picker](./images/select-upgrade-agent.png)

```plaintext
Convert the existing ASP.NET MVC pages to Blazor components in this .NET 10 application. This includes:

Before making any changes, create and switch to a new Git branch named blazor-ui-refresh. Keep all Blazor conversion changes on that branch.

Identify the MVC views, controllers, models, and services involved.
Recommend whether Blazor Server interactivity or static server rendering is most appropriate for this app.
Convert all existing pages one page at a time to use Blazor (preferably Blazor Server or Blazor WebAssembly, depending on suitability).
Remove all non-Blazor pages and ensure routing is correctly configured.
Preserve layout, validation, images, and existing user-facing behavior.
Ensure all media (images, videos, etc.) are correctly referenced and rendered in the new Blazor components.
Fix issues where the page renders blank or fails to load due to routing or layout problems.
Leverage Blazor components to make it look more modern, sleek, and aesthetic.
```

> 💡 **NOTE**
>
> That last line is deliberately vague — "modern, sleek, and aesthetic" means whatever the model decides it means. Expect your result to look different from the screenshots below, and different from the person sitting next to you. That is fine. The point of this step is that you *can* modernize a UI by asking, not that everyone lands on the same UI.
>
> If you have something specific in mind, say so. Name the color palette, ask for product cards in a responsive grid, or paste in a screenshot of a design you like. The more specific the ask, the less the model has to invent.
>
> The same applies when something breaks. If a page renders blank, a component goes missing, or routing misbehaves, describe that specific problem in the chat and let Copilot fix it before moving on.

![The Upgrade agent finds no MVC-to-Blazor scenario and proceeds with a direct code change](./images/blazor-migration.png)

If the agent asks you to confirm how to proceed, choose the default option, **Proceed directly**. This lets it make the Blazor changes outside the predefined upgrade-scenario workflow.

![Choose the default Proceed directly option when prompted](./images/confirm-direct-migration.png)

Notice what the agent says: no upgrade scenario covers MVC → Blazor, so it will do this as a **direct code change**. The Upgrade agent ships with tested scenarios for common migrations, but it is not limited to them. It is strong at understanding languages and frameworks and converting between them, and it still runs structured checks as it works, such as reading the app before it edits and building to verify its changes. Because the Upgrade agent is built on top of GitHub Copilot, you can also ask it questions and give it requests outside its predefined scenarios, just as you would any other Copilot agent.

Copilot will convert the MVC pages to Blazor components, aiming to preserve the app's functionality while giving it a more modern UI. Expect this update to take about 10–20 minutes.

> **If the conversion gets stuck or takes longer than the workshop allows:** This UI refresh is useful, but it's not required for the Azure-readiness work or later steps. Stop the agent, switch back to the **main** branch, and continue; keep the **blazor-ui-refresh** branch so you can return to it later. The prepared app and following instructions let you proceed without waiting for the UI changes.

**While the agent works, complete these steps:**

- [ ] **Follow its progress in Copilot Chat.** The agent posts paragraph-style updates describing what it has changed and what it plans to do next.
- [ ] **Inspect a code change.** When Chat reports that it edited a file, select the file or change entry to open it in the editor. Look at the diff to see what the agent changed.
- [ ] **Notice errors and recovery.** If the agent reports errors, watch how it investigates and tries to fix them. If it gets stuck, ask what went wrong and what it plans to try next.
- [ ] **Ask a question.** Ask Copilot Chat what it is doing or why it made a particular change. The agent will answer and pause; when you're ready for it to continue the conversion, send `Continue`.

This is our final page (yours may look different):

![Blazor Final Page](./images/blazor-homescreen.png)

![Blazor Final Page Store](./images/blazor-stores.png)

![Blazor Products](./images/blazor-products.png)

### ✅ Build and test the Blazor conversion

If Copilot does not automatically do this verification, then prompt copilot to build and run the app:

```plaintext
1. Build the solution to ensure no compilation errors
1. Run the application and verify all functionality
1. Check that:
   - All pages load correctly and render as Blazor components
   - Images and static content display properly
   - Sign-in still works for alice and bob (password Password1!) and the cart still holds its contents
   - No MVC views or controllers are left behind in the routing
   - The application starts cleanly from the Visual Studio Code terminal
```

Use these demo logins when you check sign-in yourself:

| Username | Password | Role | Notes |
| --- | --- | --- | --- |
| `alice` | `Password1!` | Admin, Manager | Has existing order history |
| `bob` | `Password1!` | Employee | Has existing order history |

![Modernized Application Running](./images/blazor-order.png)

> 💡 The app does the same things it did at the end of Module 2 — that is the point. Everything so far changed *how* the app runs and renders, not *what* it does.

## 2️⃣ Prepare the app code for Azure

The app runs on .NET 10 and renders through Blazor, but its code does not yet know how to work with Azure services such as Key Vault or managed identity. Nothing so far has touched that, because a framework upgrade has no reason to.

**In this step you make code changes only.** You add the code the app needs to use Azure services, but you do not create the services themselves. We will create the IaC for services in later modules.

For example, if the app has the database password hard-coded in a config file today, in this step, you wire the code to read that secret from **Azure Key Vault** instead.

You'll use the same **GitHub Copilot modernization** extension you used in Module 2, this time with its **Migrate to Azure** option.

> 💡 **How Migrate to Azure works.** Behind this option is a set of agents built specifically for moving .NET apps to Azure. The **modernize** agent coordinates the work in three stages, **assess → plan → execute**, and hands each stage to a specialized agent: an assessment coordinator, a planning coordinator, and an execution coordinator. Instead of improvising, these agents use predefined migration tasks that capture Microsoft's best practices for common changes, such as reading secrets from Key Vault or connecting to a database with a managed identity, and they build the app to check their work. You stay in control: the agent stops after planning so you can review the plan before any code changes. See [GitHub Copilot modernization overview](https://learn.microsoft.com/dotnet/azure/migration/appmod/overview) to learn more.

1. **Start Migrate to Azure.** Open the GitHub Copilot modernization extension from the Activity Bar on the left side of VS Code:

   ![The GitHub Copilot modernization icon in the VS Code Activity Bar](../02-upgrade-dotnet-with-ghcp/images/ghcp-extension.png)

   Under **QuickStart**, select **Migrate to Azure**.

   ![Migrate to Azure in the GitHub Copilot modernization extension](./images/migrate-to-azure-button.png)

   A chat opens with the prompt "Migrate this application to Azure". Notice that it runs on the **modernize** agent, the orchestrator described above.

2. **Choose what to migrate.** When the agent asks **What do you want to migrate to Azure?**, select **My entire application** and then **Submit**. This assesses the whole app; you'll narrow the scope in a later step.

   ![Choosing to migrate the entire application](./images/migrate-to-azure-scope.png)

3. **Review the assessment.** The agent runs the same **cloud readiness assessment** you saw in Module 2, because it needs to know what to change before the app can move to Azure. This time, notice that **Frameworks** shows **net10.0**: the assessment picks up the upgrade you just did. Compare it with the Module 2 report: some issues are gone because of the upgrade, and the ones left are what still stands between the app and Azure.

   ![Cloud readiness assessment showing the app on .NET 10](./images/migrate-to-azure-assessment.png)

4. **Read the agent's suggestions.** After the assessment, the agent lists what the app is today and the changes it recommends to run in Azure. It can identify work across hosting, the database, secrets, hardcoded values, and session or cache storage.

   ![The agent summarizes the current application](./images/migrate-to-azure-suggestions-today.png)

   ![The agent recommends changes to prepare the app for Azure](./images/migrate-to-azure-suggestions-changes.png)

   Notice what the agent identified and why. Ask Copilot Chat about any suggestion you don't understand, or ask what tradeoffs a change would involve. The agent is capable of helping with this broad set of Azure-readiness work; the workshop deliberately spreads it across modules so you can focus on one part at a time.

   The hosting choice is covered in Module 4, the database migration in Lab 05, and the Dockerfile in Module 6. Those items appear in the assessment because they are part of the overall journey, but we are not implementing them in this step.

5. **Narrow the scope, then move to planning.** Tell the agent to plan the application-code changes for this step, while leaving the database unchanged and saving infrastructure and containerization for their later labs:

   ```plaintext
   Proceed to planning. Include the application code changes needed to run this app on Azure. Don't generate a Dockerfile or any infrastructure-as-code files (Bicep/Terraform/ARM). I'll provision the Azure resources later, so assume they exist and read endpoints and connection strings from configuration. Don't migrate or change the database: the app must keep using the same existing SQL Server with the same connection details. Create a new branch for the changes.
   ```

   The modernize agent hands the work to the **planning-coordinator** agent, which writes the migration plan.

   ![The modernize agent delegating to the planning-coordinator agent](./images/planning-coordinator.png)

6. **Review the plan.** When the plan is ready, the agent tells you where to find it. Nothing has changed in your code yet, and the branch hasn't been created.

   ![The agent reports that the plan is ready for review](./images/migration-plan-ready.png)

   The plan is saved in the `.github/modernize` folder of your repository:

   - **`plan.md`** describes the changes the agent intends to make and why.

   Read through the tasks in the plan. Your plan may have a different number of tasks, or different ones, from the person next to you; that's expected. If the plan doesn't list its tasks, check the same folder for `tasks.json`—it may be inside a `.metadata` subfolder. You can also ask Copilot Chat:

   ```text
   Summarize the approved plan and list its tasks in order, including what each task will change. Call out any task that touches the database or creates infrastructure files.
   ```

   If anything doesn't belong, such as a task that touches the database or creates infrastructure files, edit `plan.md` directly or tell the agent in the chat.

   **Add one rule to the plan.** None of the Azure services exist yet, so the app has to keep working without them. Add this rule either by typing it in the chat and asking the agent to add it to the plan, or by navigating to the `.github/modernize` folder and editing `plan.md` directly:

   ```plaintext
   Every Azure service added by this plan must be optional and switched on only by a configuration setting; when the setting is empty, the app must run exactly as it did before without contacting Azure, and if the settings for a service are only partly filled in, the app must stop at startup with a clear error instead of silently falling back.
   ```

   This rule does two things. With no Azure settings, the app runs exactly as it does today, so you can still run it on the VM at the end of this module. And if someone fills in only part of a service's settings later, the app stops with a clear error instead of quietly ignoring Azure, which would be much harder to notice.

   If a task doesn't make sense, ask Copilot to explain it:

   ```plaintext
   For each task in the plan, explain in plain language what would go wrong in Azure without it.
   ```

7. **Run the plan.** When the plan looks right, send:

   ```plaintext
   Execute the plan.
   ```

8. **Follow the progress.** The Migrate to Azure agents don't have the dashboard you used with the Upgrade agent in Module 2; that dashboard is specific to framework upgrades. Instead, the agent *usually* writes a `progress.md` file for each task and checks off each step as it finishes. If you don't see a progress file, ask Copilot Chat: `Please create a progress.md file to track the migration's progress.` Each task follows the same pattern:

   To get a quick status update at any point, ask Copilot Chat:

   ```text
   Summarize progress against the approved plan: list completed tasks, the current task, remaining tasks, and any errors or blockers.
   ```

   - **Code migration:** the files it changes, such as the project file, `appsettings.json`, and `Program.cs`.
   - **Validation and fixing:** it builds the app, checks the libraries for known security vulnerabilities (CVEs), checks that the changes are consistent and complete, and runs any tests.
   - **Final summary:** it commits the changes and writes a `summary.md` explaining what it did.

   ![A task's progress.md file during the migration](./images/migration-progress.png)

   If you're ever unsure how far along the migration is or what it's doing, ask in the chat, for example `What task are you on, and what's left?`

9. **Review tool calls as it goes.** The agent will rebuild the app and may ask permission to run commands. Review each request, approve it when appropriate, and read the per-phase summaries as they appear instead of waiting until the end.

   ![The permissions menu with Default Permissions, Sandboxing for terminal, Allow All, and Autopilot](./images/autopilot-permissions.png)

   > 💡 **Autopilot (Preview) is another option.** Unlike **Allow All**, Autopilot lets the agent continue through the task without pausing for approval before each command, within the permissions you've granted. It can speed up this workshop, but use the review-and-approve flow above if you want to inspect the agent's actions as they happen. In a customer environment, agree on the permission level first: Autopilot trades visibility and control during execution for speed, so use it only when the customer is comfortable with that trade-off.

10. **Read the summary.** When every task is done, the agent posts a summary in the chat. It tells you:

    - which **branch** the changes are on. The agent creates a new local branch for this work from your Module 2 branch, and doesn't push anything to GitHub.
    - whether the app **builds**, and whether any **tests** ran. This app has no test projects, so expect no tests to run.
    - a table of each **task**, its **result**, and the **commit** it made, so you can review each change on its own.

    ![The agent's summary after executing the migration plan](./images/migration-summary.png)

    Notice one honest line in the summary: none of the new Azure code has been run against real Azure resources yet. That's expected, because those resources don't exist until later modules. Each task also has its own `summary.md` in the `.github/modernize/code-migration` folder with more detail.

    If the summary is too technical, ask for a plainer version:

    ```plaintext
    Summarize the changes you made at a high level, not file level.
    ```

11. **Build and run the app on the VM.** Your code is now on the new branch the agent created. Because none of the Azure settings are filled in, the app should skip Azure entirely and work exactly as before: for example, it reads its database connection from local settings instead of Key Vault, and keeps shopping carts in memory instead of Redis.

    **First, check where the database connection lives now.** We still need it to run the app, since Key Vault isn't wired up to a real Key Vault yet. Ask Copilot:

    ```plaintext
    Where is the database connection string now? We still need it to run the app since Key Vault isn't wired up yet. Put it in user secrets and run this if needed.
    ```

    **Then build and run it.** Ask Copilot to build and run the app, and open the URL it gives you. The app should look and behave exactly as it did before this step: the products load, sign-in works for both demo accounts, and the cart keeps its contents.

    If the app fails to start or something looks off, it's usually trying to reach an Azure service that doesn't exist yet. Tell Copilot what you see, and ask it to check that every Azure service falls back to the app's current behavior when its settings are empty. You can also ask Copilot to run this check for you:

    ```plaintext
    Verify the changes you made actually work. Run the app and check the behavior, don't just re-read the code. For anything you can't verify without Azure resources, say so explicitly rather than assuming it works.
    ```

> 💡 Worth opening `appsettings.json` when the run finishes. Whatever the agent decided this app needs from Azure usually lands there as empty settings — a quick read tells you what the next module has to provision.

> 🎉 **That's it — the app's code is ready for Azure.**
>
> Three modules ago this was a .NET Framework 4.8 app that only ran on Windows Server behind IIS. It now builds on .NET 10, renders through Blazor, and its code is wired to use Azure services. It is not running in Azure yet, because those services don't exist. Next module you design the Azure platform those settings expect, and Module 6 deploys the app onto it.

## 🔧 Troubleshooting common issues

### YARP errors

YARP is a tool that routes traffic when an old and a new version of an app run side by side. You chose the all-at-once upgrade in Module 2, so this app doesn't need it. If you see YARP errors:

- Ask Copilot to find where YARP is used in the app.
- Ask Copilot to remove the YARP packages, settings, and startup code.
- Rebuild the app after it is removed.

### Missing images or static files

If product images don't appear after modernization:

- Ask Copilot to check that images, styles, and other static files are in the `wwwroot` folder, which is where .NET 10 web apps serve them from.
- Ask Copilot to confirm that the app is set up to serve static files.
- Ask Copilot to check that the image paths in the pages match the files in `wwwroot`.

![Image Organization](./images/image-organization.png)

## ✅ Verification

By the end of this section, you should have:

- 🔹 Converted the MVC pages to Blazor components
- 🔹 Asked the agent what the app's code needs to work with Azure services
- 🔹 Closed the cloud readiness gaps it found in the code
- 🔹 Kept the application buildable and its behavior unchanged throughout

> **Next module preview:** Module 4 designs the Azure resources this app now expects, such as the private networks, the identities it signs in with, and the service that runs it. You plan them and have Copilot write them as Bicep files. Your instructor has already set up the real Azure environment, so your Bicep stays as files in your repository to review, not something you deploy. The app itself is deployed in Module 6.
