# Zed OpenCode ACP Watch

Non-blocking ACP wrapper for running OpenCode inside Zed with better activity visibility.

When OpenCode launches subagents, background work, long tool calls, visual checks, or review agents, Zed can look idle even though work is still moving in OpenCode's session database. This wrapper starts the real `opencode acp`, forwards ACP traffic, and emits lightweight synthetic status updates based on live OpenCode activity.

Russian documentation: [README.ru.md](README.ru.md)

## What It Does

- Runs `opencode acp` as a transparent wrapper.
- Keeps responses non-blocking by default with `OPENCODE_ACP_WATCH_HOLD=0`.
- Watches OpenCode's SQLite database for real activity.
- Tracks recursive child sessions, not only the visible parent session.
- Shows heartbeat updates such as `OpenCode active (...)` when descendant tools, assistant messages, or recent child session updates are present.
- Warns when OpenCode stops after an assistant message with no final text report, for example after a provider interruption or `finish: unknown`.
- Serializes near-simultaneous ACP startups to reduce `database is locked` failures against OpenCode's SQLite database.
- Avoids reporting the synthetic heartbeat as `completed` after `session/cancel`, so Zed does not play a misleading "done" signal while work is being restarted.
- Helps with the common case where a parent task looks stale while `oracle`, `look_at`, `Sisyphus-Junior`, or other child agents are still working.

## Requirements

- Zed with a custom ACP agent server.
- OpenCode installed locally.
- Python 3.10+.
- OpenCode's local SQLite database, normally at `~/.local/share/opencode/opencode.db`.

No third-party Python packages are required.

## Install

```sh
git clone https://github.com/YOUR-USER/zed-opencode-acp-watch.git
cd zed-opencode-acp-watch
./scripts/install.sh
```

The installer copies `bin/opencode-acp-watch` to `~/.local/bin/opencode-acp-watch` and backs up an existing file first.

## Zed Configuration

Use an absolute path in `settings.json`; Zed may not expand `~` in command paths.

```json
{
  "agent_servers": {
    "opencode": {
      "type": "custom",
      "command": "/home/YOUR_USER/.local/bin/opencode-acp-watch",
      "args": [],
      "env": {
        "OPENCODE_ACP_WATCH_HOLD": "0",
        "OPENCODE_ACP_WATCH_POLL_SEC": "2",
        "OPENCODE_ACP_WATCH_ACTIVE_WINDOW_SEC": "1800",
        "OPENCODE_ACP_WATCH_STATUS_RECENT_WINDOW_SEC": "120",
        "OPENCODE_ACP_WATCH_STATUS_IDLE_POLL_SEC": "10"
      }
    }
  }
}
```

Restart the Zed/OpenCode agent session after changing the wrapper or Zed settings. Existing ACP sessions keep the wrapper code and environment they were started with.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `OPENCODE_ACP_WATCH_REAL` | `~/.opencode/bin/opencode` | Real OpenCode executable. |
| `OPENCODE_ACP_WATCH_DB` | `~/.local/share/opencode/opencode.db` | OpenCode SQLite database. |
| `OPENCODE_ACP_WATCH_LOG` | `~/.local/state/zed-opencode-acp-watch/opencode-acp-watch.log` | Wrapper JSONL log. |
| `OPENCODE_ACP_WATCH_START_LOCK` | `~/.local/state/zed-opencode-acp-watch/opencode-acp-start.lock` | File lock used to serialize initial `opencode acp` startup. |
| `OPENCODE_ACP_WATCH_START_LOCK_TIMEOUT_SEC` | `15` | How long a second startup waits for the startup lock. |
| `OPENCODE_ACP_WATCH_START_LOCK_HOLD_SEC` | `5` | How long the first startup keeps the lock while OpenCode initializes. |
| `OPENCODE_ACP_WATCH_HOLD` | `0` | Keep non-blocking mode. Legacy hold mode is still available with `1`. |
| `OPENCODE_ACP_WATCH_POLL_SEC` | `2` | Poll interval while activity is visible. |
| `OPENCODE_ACP_WATCH_ACTIVE_WINDOW_SEC` | `1800` | Window for active running/pending tools and unfinished assistant messages. |
| `OPENCODE_ACP_WATCH_STATUS_RECENT_WINDOW_SEC` | `120` | Window for recent descendant session/part activity. |
| `OPENCODE_ACP_WATCH_STATUS_MAX_SEC` | same as active window | Maximum lifetime of a status monitor for one prompt. |
| `OPENCODE_ACP_WATCH_STATUS_IDLE_POLL_SEC` | `10` | Poll interval after startup when no activity is currently visible. |

## Diagnostics

```sh
./scripts/diagnose.sh
```

The script prints recent sessions, running/pending tools, and OpenCode DB/log mtimes. It is useful when Zed looks idle but OpenCode is still updating child sessions.

## Notes

This wrapper does not modify OpenCode sessions, kill processes, or edit projects. It only observes OpenCode's database and sends ACP status updates to Zed.

Old `running` rows in OpenCode's database can be stale. Treat a task as live only when its session, child sessions, parts, WAL file, or OpenCode log keep updating.
