# Zed OpenCode ACP Watch

Неблокирующая ACP-обёртка для запуска OpenCode в Zed с более честной индикацией активности.

Когда OpenCode запускает сабагентов, фоновые задачи, долгие tool calls, визуальные проверки или review-агентов, Zed может выглядеть так, будто всё остановилось. При этом работа продолжает идти в базе сессий OpenCode. Эта обёртка запускает настоящий `opencode acp`, прозрачно прокидывает ACP-трафик и отправляет лёгкие статусные обновления по реальной активности OpenCode.

English documentation: [README.md](README.md)

## Что Решает

- Запускает `opencode acp` через прозрачную обёртку.
- По умолчанию не держит ответы: `OPENCODE_ACP_WATCH_HOLD=0`.
- Следит за SQLite-базой OpenCode.
- Учитывает рекурсивные дочерние сессии, а не только видимую родительскую строку.
- Показывает heartbeat вида `OpenCode active (...)`, если есть активные descendant tools, assistant messages или свежие обновления дочерних сессий.
- Закрывает частый случай: родительская задача выглядит старой, но `oracle`, `look_at`, `Sisyphus-Junior` или другие дочерние агенты ещё работают.

## Требования

- Zed с custom ACP agent server.
- Локально установленный OpenCode.
- Python 3.10+.
- Локальная SQLite-база OpenCode, обычно `~/.local/share/opencode/opencode.db`.

Сторонние Python-пакеты не нужны.

## Установка

```sh
git clone https://github.com/YOUR-USER/zed-opencode-acp-watch.git
cd zed-opencode-acp-watch
./scripts/install.sh
```

Установщик копирует `bin/opencode-acp-watch` в `~/.local/bin/opencode-acp-watch` и перед заменой делает backup существующего файла.

## Настройка Zed

В `settings.json` лучше указывать абсолютный путь: Zed может не раскрывать `~` в поле `command`.

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

После изменения обёртки или настроек Zed нужно перезапустить Zed/OpenCode agent session. Уже запущенные ACP-сессии остаются на старом коде и старом окружении.

## Настройки

| Переменная | По умолчанию | Значение |
| --- | --- | --- |
| `OPENCODE_ACP_WATCH_REAL` | `~/.opencode/bin/opencode` | Настоящий исполняемый файл OpenCode. |
| `OPENCODE_ACP_WATCH_DB` | `~/.local/share/opencode/opencode.db` | SQLite-база OpenCode. |
| `OPENCODE_ACP_WATCH_LOG` | `~/.local/state/zed-opencode-acp-watch/opencode-acp-watch.log` | JSONL-лог обёртки. |
| `OPENCODE_ACP_WATCH_HOLD` | `0` | Неблокирующий режим. Старый режим удержания можно включить через `1`. |
| `OPENCODE_ACP_WATCH_POLL_SEC` | `2` | Частота опроса, когда активность видна. |
| `OPENCODE_ACP_WATCH_ACTIVE_WINDOW_SEC` | `1800` | Окно для активных `running`/`pending` tools и незавершённых assistant messages. |
| `OPENCODE_ACP_WATCH_STATUS_RECENT_WINDOW_SEC` | `120` | Окно для свежей активности дочерних session/part. |
| `OPENCODE_ACP_WATCH_STATUS_MAX_SEC` | равно active window | Максимальная жизнь status-monitor для одного prompt. |
| `OPENCODE_ACP_WATCH_STATUS_IDLE_POLL_SEC` | `10` | Частота опроса после старта, если активность пока не видна. |

## Диагностика

```sh
./scripts/diagnose.sh
```

Скрипт показывает свежие сессии, `running`/`pending` tools и время изменения DB/логов OpenCode. Это полезно, когда Zed выглядит пустым, но OpenCode продолжает двигать дочерние сессии.

## Замечания

Обёртка не меняет OpenCode-сессии, не убивает процессы и не редактирует проекты. Она только читает базу OpenCode и отправляет статусные ACP-обновления в Zed.

Старые строки `running` в базе OpenCode могут быть stale. Считать задачу живой стоит только если продолжают обновляться сама сессия, дочерние сессии, parts, WAL-файл или лог OpenCode.
