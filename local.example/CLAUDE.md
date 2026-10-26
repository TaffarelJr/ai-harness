## This machine

Notes that are true only here and apply in every folder: a proxy,
which tools are present, what is blocked. This fragment is appended to
the generated user-level `CLAUDE.md` and is never committed.
Account names belong in the per-folder fragments
(`Personal.CLAUDE.md`, `Work.CLAUDE.md`), not here.

- A corporate proxy inspects TLS. `curl` fails its certificate
  revocation check for most hosts; use `Invoke-RestMethod` instead.
- `<a blocked host>` is unreachable from this machine; nothing should
  try to talk to it.
