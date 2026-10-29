# Work repositories

Everything under this folder belongs to my employer. Its repositories
carry their own instructions, and those win over anything here or in my
personal defaults.

- Work is planned in Azure DevOps: epics, features, stories, and
  sprints live there. Use the Azure DevOps MCP server named below when
  it answers; when it does not, fall back to the `az` CLI or the REST
  API with the work credential, and say so.
- Code, pull requests, and CI/CD live on GitHub Enterprise. Use the
  GitHub MCP server named below when it answers; when it does not,
  fall back to `gh` with the work account named below.
- A pull request references the work item it serves as `AB#<id>` on the
  first line of its description, so the two systems link. Never in a title
  or in a commit message.
- On my own pull request, reply to a review thread only when the reply adds
  something; an emoji, or nothing, is fine. Resolve a bot's thread once it
  is dealt with, and leave a person's for them to resolve.
- Only a person merges a pull request.
- Nothing from these repositories — code, data, or conversation —
  leaves the machine except to the AI providers the employer has
  approved. No external hooks, webhooks, or push services.
