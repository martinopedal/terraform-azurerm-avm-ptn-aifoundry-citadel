# Copilot Instructions - terraform-azurerm-avm-ptn-aifoundry-citadel

## Memory & context discipline — read FIRST (and write), every task

Before designing, modifying, **or asking** anything, load context from ALL memory
sources, and do **NOT** re-discover, re-derive, or re-ask Martin for anything already
recorded (credential paths, App/installation IDs, runner config, decisions, conventions):

1. **Stored Copilot memories** (shown in the prompt) + this repo's conventions.
2. **`.squad/` decision ledger** — `.squad/decisions.md`, ADRs in `.squad/decisions/`,
   and relevant agent `history.md` files.
3. **Martin's memory vault** — `C:\git\memory-vault\` (skills in `.copilot/skills/`,
   `wiki/`, decisions). **Grep it for the topic first** (credentials, file paths,
   App/installation IDs, runner/auth setup) before hunting on disk or asking Martin.

When you learn a durable fact (a path, ID, root cause, convention), **write it to memory
immediately** (`store_memory`) and/or `.squad/decisions/inbox/` so it is never
re-discovered. **Periodically consolidate**: when wrapping up a work stream, sweep the
decisions you made + `.squad/decisions.md` + accumulated context and ensure every
durable, reusable fact is captured in **stored memory** — not left only in the ledger
or the vault.

---

