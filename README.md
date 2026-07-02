# Zed OpenCode ACP Watch

Non-blocking ACP wrapper for running OpenCode inside Zed with better activity visibility.

When OpenCode launches subagents, background work, long tool calls, visual checks, or review agents, Zed can look idle even though work is still moving in OpenCode's session database. This wrapper starts the real `opencode acp`, forwards ACP traffic, and emits lightweight synthetic status updates based on live OpenCode activity.

Russian documentation: [README.ru.md](README.ru.md)

## What It Does

- Runs `opencode acp` as a transparent wrapper.
- Keeps responses non-blocking by default with `OPENCODE_ACP_WATCH_HOLD=0`.
- Watches OpenCode's SQLite database for real activity.
- Tracks recursive child sessions, not only the visible parent session.
- Shows a lightweight Russian preflight status before each prompt: CPU/load average, available RAM, swap, `opencode acp` process count, the current session's local queue, open todos, and a rough ETA.
- Estimates current-session context weight during preflight from total tokens, session-tree age, message count, parts, and tool parts.
- Warns when it is better to start a fresh session from a short handoff file such as `AI_CONTEXT.md`.
- Writes ETA JSONL statistics so predictions can later be compared against actual runtime and tuned.
- Shows Russian heartbeat updates such as `OpenCode активен: ...` when descendant tools, assistant messages, or recent child session updates are present.
- Periodically re-announces the synthetic status so Zed can restore the indicator after a reconnect/re-render drops the visible progress row.
- Marks the status as `failed` when an assistant message stops updating for too long and no tools are active, making a stalled provider/model stream visible.
- Does not inject raw `session.title` into synthetic heartbeat rows: OpenCode child-session titles may be English, but the wrapper keeps them only in logs for diagnostics.
- Marks the synthetic status as `failed` when OpenCode stops after an assistant message with no final text report, for example after a provider interruption or `finish: unknown`.
- Serializes near-simultaneous ACP startups to reduce `database is locked` failures against OpenCode's SQLite database.
- Reports the synthetic heartbeat as `failed` after `session/cancel`, so Zed does not play a misleading "done" signal or leave stale progress visible while work is being restarted.
- Extends the status monitor after `OPENCODE_ACP_WATCH_STATUS_MAX_SEC` when OpenCode's DB still shows activity, so long-running live tasks do not lose their indicator.
- Helps with the common case where a parent task looks stale while `oracle`, `look_at`, `Sisyphus-Junior`, or other child agents are still working.

## Requirements

- Zed with a custom ACP agent server.
- OpenCode installed locally.
- Python 3.10+.
- OpenCode's local SQLite database, normally at `~/.local/share/opencode/opencode.db`.

No third-party Python packages are required.

## Install

```sh
git clone https://github.com/shumkiiv/zed-opencode-acp-watch.git
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
        "OPENCODE_ACP_WATCH_PREFLIGHT": "1",
        "OPENCODE_ACP_WATCH_ETA_STATS": "1",
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
| `OPENCODE_ACP_WATCH_PREFLIGHT` | `1` | Show startup resource and local queue status before a prompt. |
| `OPENCODE_ACP_WATCH_PREFLIGHT_DB_TIMEOUT_SEC` | `0.5` | Maximum wait for the short read-only OpenCode DB query used by preflight. |
| `OPENCODE_ACP_WATCH_CONTEXT_WARN` | `1` | Add a preflight warning when the current session is context-heavy. |
| `OPENCODE_ACP_WATCH_CONTEXT_FILES` | `AI_CONTEXT.md:AGENT_CONTEXT.md:HANDOFF.md:STATUS.md:NEXT_STEPS.md:.ai/context.md:.ai/handoff.md:docs/AI_CONTEXT.md` | Short handoff files the wrapper looks for in the session working directory. |
| `OPENCODE_ACP_WATCH_CONTEXT_INPUT_WARN_TOKENS` / `OPENCODE_ACP_WATCH_CONTEXT_INPUT_HEAVY_TOKENS` | `3000000` / `8000000` | Total input-token thresholds for the session tree. |
| `OPENCODE_ACP_WATCH_CONTEXT_PART_WARN_COUNT` / `OPENCODE_ACP_WATCH_CONTEXT_PART_HEAVY_COUNT` | `600` / `1500` | Part-count thresholds for the session tree. |
| `OPENCODE_ACP_WATCH_CONTEXT_TOOL_WARN_COUNT` / `OPENCODE_ACP_WATCH_CONTEXT_TOOL_HEAVY_COUNT` | `120` / `300` | Tool-part thresholds for the session tree. |
| `OPENCODE_ACP_WATCH_CONTEXT_MESSAGE_WARN_COUNT` / `OPENCODE_ACP_WATCH_CONTEXT_MESSAGE_HEAVY_COUNT` | `160` / `400` | Message-count thresholds for the session tree. |
| `OPENCODE_ACP_WATCH_CONTEXT_AGE_WARN_SEC` | `21600` | Session-tree age warning threshold: 6 hours. |
| `OPENCODE_ACP_WATCH_ETA_STATS` | `1` | Record ETA accuracy statistics. |
| `OPENCODE_ACP_WATCH_ETA_STATS_PATH` | `~/.local/state/zed-opencode-acp-watch/opencode-acp-watch-eta.jsonl` | JSONL file with the prediction, actual duration, and whether the duration landed in the predicted range. |
| `OPENCODE_ACP_WATCH_ACTIVE_WINDOW_SEC` | `1800` | Window for active running/pending tools and unfinished assistant messages. |
| `OPENCODE_ACP_WATCH_STATUS_RECENT_WINDOW_SEC` | `120` | Window for recent descendant session/part activity. |
| `OPENCODE_ACP_WATCH_STATUS_MAX_SEC` | same as active window | Maximum lifetime of a status monitor for one prompt. |
| `OPENCODE_ACP_WATCH_STATUS_IDLE_POLL_SEC` | `10` | Poll interval after startup when no activity is currently visible. |
| `OPENCODE_ACP_WATCH_STATUS_REANNOUNCE_SEC` | `60` | How often live activity re-sends a full synthetic `tool_call` so Zed can restore a lost status row. `0` disables it. |
| `OPENCODE_ACP_WATCH_STALE_ASSISTANT_SEC` | `600` | Seconds without updates on an unfinished assistant message, with no active tools, before treating the stream as stalled. `0` disables it. |
| `OPENCODE_ACP_WATCH_CANCEL_GRACE_SEC` | `30` | How long to keep status alive after `session/cancel` while checking whether OpenCode continues writing session activity. |

## Diagnostics

```sh
./scripts/diagnose.sh
```

The script prints recent sessions, running/pending tools, and OpenCode DB/log mtimes. It is useful when Zed looks idle but OpenCode is still updating child sessions.

## Notes

This wrapper does not modify OpenCode sessions, kill processes, or edit projects. It only observes OpenCode's database and sends ACP status updates to Zed.

The preflight status cannot see the model provider's external queue. It gives a local estimate from `/proc/loadavg`, `/proc/meminfo`, the process list, and one short read-only query against OpenCode's SQLite database. The estimate also uses the number of parallel ACP sessions and open todos in the current session tree. In normal use this is cheaper than a regular heartbeat poll; if the database is busy, the query is capped by `OPENCODE_ACP_WATCH_PREFLIGHT_DB_TIMEOUT_SEC`.

ETA is intentionally coarse: `до 1 мин`, `1-3 мин`, `3-10 мин`, or `10+ мин`. The default prediction is conservative after local calibration: a clean local machine starts at `1-3 мин`; active tools, open todos, or several ACP sessions move the estimate to `3-10 мин` or `10+ мин`. After completion, cancellation, timeout, or monitor shutdown, one JSONL row is appended to `OPENCODE_ACP_WATCH_ETA_STATS_PATH` with `eta_label`, actual `elapsed_sec`, outcome, `eta_hit`, and the resource snapshot. That history is meant for tuning thresholds to a specific machine and project mix.

The context check does not compact or delete OpenCode history. It only warns that the current session should be wrapped up, a short handoff file should be updated, and work should continue in a fresh session. When the working directory contains `AI_CONTEXT.md` or another file from `OPENCODE_ACP_WATCH_CONTEXT_FILES`, the wrapper includes that file name in the warning.

After Zed sends `session/cancel`, the status monitor does not immediately close the synthetic status. It waits `OPENCODE_ACP_WATCH_CANCEL_GRACE_SEC` and checks whether OpenCode wrote newer session, part, or message activity after that grace window. If work keeps moving, the status remains `in_progress`; otherwise it closes as cancelled.

If Zed loses the visible synthetic status row, ordinary `tool_call_update` messages may not be visible. During live activity the wrapper therefore re-sends a full synthetic `tool_call` with the same `toolCallId` every `OPENCODE_ACP_WATCH_STATUS_REANNOUNCE_SEC`.

If the provider/model stream stalls and OpenCode leaves an unfinished assistant message without newer parts/tools, the wrapper closes the synthetic status as `failed` after `OPENCODE_ACP_WATCH_STALE_ASSISTANT_SEC`. It does not send a new prompt automatically and does not cancel the process; the next action stays under user control.

Old `running` rows in OpenCode's database can be stale. Treat a task as live only when its session, child sessions, parts, WAL file, or OpenCode log keep updating.
