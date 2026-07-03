# Changelog

## Unreleased

- Add non-blocking ACP wrapper for OpenCode in Zed.
- Add descendant-aware activity heartbeat for parent/child OpenCode sessions.
- Mark the Zed synthetic status as failed when OpenCode activity settles but the last assistant message has no final text report.
- Add preflight context-weight warnings with handoff-file hints for long or token-heavy sessions.
- Re-announce live synthetic statuses periodically so Zed can restore a lost progress row after reconnect/re-render.
- Mark stale unfinished assistant streams as failed when they stop updating and no tools are active.
- Add hard execution timeouts for SQLite status queries so large OpenCode databases do not freeze startup/preflight.
- Add English and Russian documentation.
- Add installer and diagnostics scripts.
