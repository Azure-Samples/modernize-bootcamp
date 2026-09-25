# 🧭 Setup & GitHub Copilot Essentials

This page is a **reference, not a lab**.

Every module in this bootcamp drives GitHub Copilot Chat. This page is the shared background those modules assume — what the dropdowns do, how to give Copilot the right context, what it costs, and how to pull it back when it goes off the rails. Read it once before starting the labs, and feel free to come back to it whenever a module says something you do not recognise.

## 🎛️ Modes

A row of controls sits under the chat input. As of VS Code 1.135 you get an **agent** picker, a **model** picker, a **reasoning level**, and — on the line below — where the session runs (**local** or **cloud**) and its **permission level** (**Default permissions** or **Allow all**).

The agent picker is the one that decides how much rope you hand it. The built-in choices sit at the top; any custom or extension-provided agents are listed underneath, which is why the list gets long once you install modernization tooling.

| Mode | What it does | Reach for it when |
| --- | --- | --- |
| **Ask** | Answers questions. Touches nothing. | You want to understand something first — "what did `machineKey` actually do?" |
| **Plan** | Reads the codebase and writes a plan you can open, edit, and reject. Still touches no code. | The change set is unknown |
| **Agent** | Edits files, runs commands, and iterates until the build is clean | You already know what you want done |

The rule worth internalising: **if you cannot roughly predict the change set in advance, plan first.** A plan is a document you can argue with. You can strike out a section, defer part of it, share it with a customer, or throw it away for the cost of nothing.

### Where the session runs

The **Local** control on the second row is the session target — where the agent actually executes. **Leave it on Local for everything in this bootcamp.** It runs in VS Code on your machine, against your current workspace, with access to your extensions and tools, which is exactly what the modernization tooling needs.

It is worth knowing what the other options are, because they are the answer when a customer asks how this scales:

| Target | Where it runs | Worth it when |
| --- | --- | --- |
| **Local** | VS Code on your machine, current workspace | The default. Interactive work needing VS Code extensions and tools |
| **Copilot** | Your machine, current folder or an isolated Git worktree | You want the agent's changes kept off your working copy |
| **Claude** / **Codex** | Your machine | You want a specific provider's capabilities |
| **Cloud** | GitHub's infrastructure, returning a pull request | A well-scoped task that can run without you and benefits from team review |

Switching target mid-session is a **handoff** — VS Code carries the conversation and context across, so you can plan locally and hand the execution somewhere else. The same menu has **New Chat Session** (`Ctrl+N`), which is what you want when you move to unrelated work.

## 🧠 Models

Model decides how much thinking you are paying for. The list in the picker changes as new models ship, so think in two categories rather than memorising names.

| Category | Good at | Use for |
| --- | --- | --- |
| **Reasoning models** | Holding a whole solution in view at once; catching cross-cutting assumptions that need several files read together | Assessment, plan mode, anything that has already failed twice |
| **Fast models** | Well-specified mechanical work | Converting one page, adding an endpoint whose shape you decided, renaming things |

Three practical notes:

- **Hover a model in the picker** to see its cost tier — Low, Medium, or High. An assessment across a whole solution is worth the high tier. Renaming a file is not.
- **When the agent stalls or loops, switch to a stronger model rather than rephrasing the prompt a fourth time.** The conversation context carries over when you change models.
- **Do not switch mid-task** while the agent is actively executing. Let it finish or stop it first.

### Reasoning level

Next to the model picker is a **reasoning level** — how hard the model thinks before answering. You rarely set this yourself: pick a model and it arrives with a default level already selected, and **that default is fine for everything in this bootcamp.**

Higher levels produce more thinking tokens, which costs both time and credits. Raise it only for a genuinely hard problem — an architectural decision, or a bug that has already survived two attempts — and drop it back afterwards.

## 🤖 Agents

An **agent** is Copilot configured for a specific job — its own instructions, its own tool list, sometimes its own verified workflow. You select one from the agent picker or summon it by name with `@`.

The difference matters. General chat works from model memory and improvises. A purpose-built agent like `@upgrade` runs a structured, tool-verified workflow: it loads current tested guidance, uses real compiler and dependency analysis to find breaking changes, and validates each step with a build before moving on.

The one you will use in this bootcamp is **`@upgrade`**, added by the GitHub Copilot upgrade extension in Module 02. It enforces a three-stage workflow:

| Stage | What happens |
| --- | --- |
| **Assessment** | Analyses project structure, dependencies, and API usage to find what will break |
| **Planning** | Writes a `plan.md` you can read, edit, and reject before anything changes |
| **Execution** | Works through that plan task by task, validating with a real build after each one |

Two things follow from that shape, and both are worth carrying into customer conversations:

- **The plan is something you can act on, not just read.** It comes back in chat as structured steps with options, and is written to `plan.md` as the source of truth — so to change the approach you edit the markdown rather than re-prompting and hoping.
- **It commits after each task.** A task that goes wrong is one `git` operation to undo, not an unpickable mess.

When you start it, a setup modal usually asks for a **Flow Mode**: **guided** stops after assessment and planning so you can inspect and redirect, while **automatic** runs end to end and pauses only when blocked. Guided is the safer choice in an unfamiliar codebase, or when a customer wants to approve each stage.

## 📎 Context

Copilot answers well when it knows what it is looking at, and produces confident generic nonsense when it does not.

- **Point at specific things** with `#` — `#file`, `#folder`, or a symbol name. Use this whenever your prompt is ambiguous about scope.
- **Describe the architecture up front.** "This is a single ASP.NET Core Blazor Server app. It has no AppHost, no microservices, and no separate API project" prevents an entire category of wrong answer.
- **Say "base this on what is actually in this working copy."** Otherwise Copilot happily assumes the shape of a sample it has seen before — a real problem in this bootcamp, where everyone's Module 02 output differs slightly.
- **Attach images and screenshots** when the question is visual.
- **Reference environment context** — terminal output, source control changes, test failures — instead of pasting it in by hand.

Two related mechanisms worth knowing exist, though no module here requires you to configure them: **custom instructions** files apply project-wide standards to every request, and **MCP servers** give agents tools and guidance from outside your workspace. If Copilot asks permission to read files outside the workspace during a module, that is usually an MCP server loading reference material, and it is safe to approve.

## ✍️ Prompting

Five rules cover most of it.

1. **Be explicit about the outcome.** "Convert this app to .NET 10" can get you a framework-only bump that compiles and is otherwise untouched. Spell out that you want it modernised.
2. **Ask for a plan before code.** "List the files you would add or change, the packages you would add, and the risks — before writing any code."
3. **Say what you do *not* want.** Constraints are as useful as requirements: "Do not add a separate API project. Do not introduce a new data access layer."
4. **One step at a time, then build.** Long compound prompts fail in ways that are hard to unpick.
5. **Push back.** If the response adds architecture the problem does not need, say so and ask it to try again inside the existing structure. Arguing with it is cheaper than accepting it.

## 🔒 Staying in control

The **permissions** dropdown sets how much autonomy the agent has for the current session.

| Level | Behaviour |
| --- | --- |
| **Default permissions** | Asks when your approval settings don't already cover the action |
| **Allow all** | Runs tool calls without asking |
| **Autopilot (Preview)** | Works autonomously within permissions — see below |

When a tool asks for approval you choose the scope: this once, this session, this workspace, or always. Clear them later with **Chat: Reset Tool Confirmations**, or review them individually with **Chat: Manage Tool Approval**, both from the Command Palette.

> ⚠️ **Autopilot**
>
> Autopilot sits at the bottom of that same permissions list, marked **Preview**. It is the most autonomous setting available: it keeps iterating until it decides the task is complete, retries on errors, and **answers its own clarifying questions rather than stopping to ask you.**
>
> That last behaviour is the one to think about. It is what makes Autopilot good for a long mechanical run you are content to review at the end. It is also what makes it the wrong choice any time the question it would have asked you is the interesting part — reviewing a plan, choosing between two designs, deciding whether a proposed change is in scope.
>
> It consumes AI credits the same way interactive chat does, and VS Code shows a warning the first time you select it.

Whatever level you pick, the review still belongs to you.

## 🛑 Reining it in

Agents go off track. Recovering is a skill, and it is mostly about acting early.

| Situation | What to do |
| --- | --- |
| It is heading the wrong way, mid-run | **Send a message while the request is still running** to steer it, or queue a follow-up for when it finishes |
| It has gone badly wrong | **Stop it**, then send a new prompt rather than trying to correct in place |
| It paused or stopped mid-task | Tell it `continue` |
| The last few turns made things worse | Use **checkpoints** to rewind to a known good state — far better than fixing cascading errors forward |
| It is looping on the same error | Switch to a stronger model and tell it to continue. Context carries over |
| Long conversation, answers getting vaguer | `/compact` to summarise older context — optionally `/compact focus on the API design decisions` |
| You want to try a different approach | `/fork` to branch the conversation instead of re-prompting from scratch |
| Moving to an unrelated task | Start a new session with `Ctrl+N`. Do not pile unrelated work into one thread |

The general rule: **two failed attempts means change something structural** — the model, the scope, or the context — rather than trying a third wording.

## 💰 What it costs

Copilot plans include a monthly allowance of **AI credits**. Different actions consume them at different rates depending on the model and how many tokens are processed.

Four places to see the number:

| Where | What it tells you |
| --- | --- |
| Hover a model in the picker | Its cost tier — Low, Medium, or High |
| Hover a chat response | Credits consumed by that single turn |
| Hover the context window control in the chat input | Running total for the whole session |
| Copilot status dashboard in the Status Bar | Percentage of your monthly allowance used |

Four levers, biggest first:

1. **Match the model to the task.** The single largest factor.
2. **Plan before you implement.** Planning is cheap; generating code you throw away is not.
3. **Keep context lean.** `/compact` long conversations, and start fresh sessions for unrelated work — otherwise every request pays to reprocess history that no longer matters.
4. **Disable tools you are not using.** Every tool call consumes context.

Run `/chronicle:cost-tips` in any session for recommendations based on your own recent activity.

## 🔧 When it goes wrong

| Symptom | Likely cause | Try this |
| --- | --- | --- |
| Answers are generic, or describe code you do not have | It is guessing at your project shape | Describe the architecture explicitly and `#`-reference the real files |
| Same build error recurring across attempts | Model too small for the reasoning required | Switch to a reasoning model and tell it to continue |
| Agent loops on one task | Scope too large, or context polluted | Stop, `/compact` or start fresh, and re-scope to one step |
| Edits contradict the plan it just wrote | Context lost over a long run | Rewind to a checkpoint and re-anchor it on the plan file |
| It stalls waiting on approvals | Every tool call is prompting | Approve for the session, or raise the permission level |
| It changed more than you expected | Agent mode on an under-specified prompt | Rewind, then re-run in plan mode first |
| It asks to read files outside the workspace | An MCP server loading reference guidance | Normally safe to approve |

## 📚 Go deeper

- [GitHub Copilot Fundamentals](https://learn.microsoft.com/training/paths/copilot/) — the full Microsoft Learn path, if you want the complete picture
- [Best practices for using AI in VS Code](https://code.visualstudio.com/docs/agents/best-practices)
- [Manage approvals and permissions](https://code.visualstudio.com/docs/agents/run/approvals) — permission levels and Autopilot in detail
- [Optimize AI credit usage](https://code.visualstudio.com/docs/agents/guides/optimize-usage)
- [Choose and configure language models](https://code.visualstudio.com/docs/agent-customization/language-models)
- [Custom agents in VS Code](https://code.visualstudio.com/docs/agent-customization/custom-agents)

---

Next: [Module 01: Assessment →](../labs/day-1/01-assesment/Readme.md)
