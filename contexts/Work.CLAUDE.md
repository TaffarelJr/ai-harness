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
- A pull request always references the work item it serves as `AB#<id>`,
  so the two systems link.
- Only a person merges a pull request.
- Nothing from these repositories — code, data, or conversation —
  leaves the machine except to the AI providers the employer has
  approved. No external hooks, webhooks, or push services.
