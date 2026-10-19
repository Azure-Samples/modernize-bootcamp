# 🗣️ Talking Points

Waiting on the agent? Use this page while a long step runs. **You don't need to read it all.** Pick the one topic that interests you most, read its **Start here** link, and come back for more if you have time. Your instructor may also lead a discussion on these topics.

Everything linked here is public documentation.

## 1. Leading modernization conversations with customers

**Think about:** Which of your customers could be good modernization candidates? Who has aging Java or .NET apps, framework upgrades, technical debt, or apps they're already discussing moving to Azure?

- **Start here:** [Modernization agent overview](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/modernization-agent/overview). It frames a customer conversation as **Assess → Plan → Execute**.
- **Go deeper:** [GitHub Copilot modernization documentation](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/). A good page to bookmark, with Java, .NET, C++, JavaScript/TypeScript, CLI, assessment, and migration guidance.

## 2. Extra GitHub Copilot modernization tools

**Think about:** Which of these would your customers actually use? Pick the one you're curious about.

- **Custom skills:** teach Copilot your organization's standards. [Adding agent skills for GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
- **Agents window in VS Code:** assign work to agents and review the results across projects. [Use the Agents window](https://code.visualstudio.com/docs/agents/run/agents-window)
- **Modernization CLI:** run modernization from the terminal. [Quickstart: install and use the modernization agent](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart)
- **Modernization plugin:** a multi-agent workflow for assessment, planning, and execution in Copilot CLI. [GitHub Copilot modernization repository](https://github.com/microsoft/github-copilot-modernization)

## 3. Choosing and switching models

**Think about:** When would a different model give better results for a modernization task?

- **Start here:** [Changing the AI model for GitHub Copilot Chat](https://docs.github.com/copilot/how-tos/use-ai-models/change-the-chat-model). How to switch models in VS Code, and why they have different strengths.
- **Go deeper:** [AI language models in VS Code](https://code.visualstudio.com/docs/agent-customization/language-models). A simple rule of thumb: use a faster model for quick questions and small edits, and a stronger reasoning model for complex refactoring, architecture decisions, or multi-step work.

## 4. Tokenomics: how usage drives cost

**Think about:** Model choice isn't only about quality, it's also about cost. How would you explain that to a customer?

- **Start here:** [Changing the AI model for GitHub Copilot Chat](https://docs.github.com/copilot/how-tos/use-ai-models/change-the-chat-model). Different models use AI credits at different rates.
- **Go deeper:** [AI language models in VS Code](https://code.visualstudio.com/docs/agent-customization/language-models). Turning up a reasoning model's effort produces more thinking tokens, which uses more credits.
