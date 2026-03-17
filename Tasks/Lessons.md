# Lessons

Read this file at the start of every session and apply the rules before planning, editing, testing, or closing tasks. When persistent rules, lessons, skills, toolkits, hooks, or bootstrap config change locally, mirror the updates into the setup repo regularly, ideally in the same workstream before closing the task.

| Date | What went wrong | Rule for next time |
| --- | --- | --- |
| 2026-03-16 | A telecom-skill plan initially missed explicit guidance to consider subagents for parallel log review and trace-capture planning. | For debugging and troubleshooting work, explicitly consider whether subagents would speed up log analysis, trace inspection, or capture planning before finalizing the plan or execution. |
| 2026-03-16 | Persistent workflow preferences were not encoded globally across Cursor config and the setup bootstrap repo. | When a user requests cross-session or cross-machine behavior, implement it via global Cursor rules or config, persist it in `Tasks/Lessons.md`, and mirror it into the setup repo. |
| 2026-03-16 | GUI-managed telecom platforms were at risk of direct backend edits even when an authoritative admin dashboard existed. | For FreePBX, GoIP, Yeastar, and similar systems, prefer the official admin/dashboard UI and browser or MCP tools first; only edit backend files when the UI is not the authoritative path or the user explicitly asks for it. |
| 2026-03-16 | Implementation could drift when new decisions appeared that were not already resolved in the accepted plan. | During implementation, pause and ask for guidance before taking any product, architecture, configuration, or workflow decision that was not already approved in the accepted plan. |
| 2026-03-16 | Plans were not always followed by a deep gap review and structured decision questions before execution started. | After creating a plan, review it thoroughly, suggest improvements, and ask all unresolved questions as multiple-choice options before implementation begins. |
| 2026-03-16 | Persistent local rules, lessons, skills, and toolkits could change without the setup repo being refreshed in the same workstream. | When persistent workflow files or bundled toolkits change locally, mirror the updates into the setup repo before closing the task unless the user explicitly says not to. |
