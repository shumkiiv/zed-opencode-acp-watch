# Zed OpenCode ACP Watch

Неблокирующая ACP-обёртка для запуска OpenCode в Zed с более честной индикацией активности.

Когда OpenCode запускает сабагентов, фоновые задачи, долгие tool calls, визуальные проверки или review-агентов, Zed может выглядеть так, будто всё остановилось. При этом работа продолжает идти в базе сессий OpenCode. Эта обёртка запускает настоящий `opencode acp`, прозрачно прокидывает ACP-трафик и отправляет лёгкие статусные обновления по реальной активности OpenCode.

English documentation: [README.md](README.md)

## Что Решает

- Запускает `opencode acp` через прозрачную обёртку.
- По умолчанию не держит ответы: `OPENCODE_ACP_WATCH_HOLD=0`.
- Следит за SQLite-базой OpenCode.
- Учитывает рекурсивные дочерние сессии, а не только видимую родительскую строку.
- Перед стартом prompt показывает лёгкий preflight-статус на русском: CPU/load average, доступную RAM, swap, число `opencode acp` процессов, локальную очередь текущей сессии, открытые todo и примерную ETA.
- В preflight оценивает тяжесть контекста текущей сессии: суммарные tokens, возраст дерева сессии, число сообщений, parts и tool parts.
- Предупреждает, когда лучше начать новую сессию с коротким handoff-файлом, например `AI_CONTEXT.md`.
- Пишет JSONL-статистику ETA, чтобы позже сравнить прогноз с фактическим временем и скорректировать пороги.
- Показывает русскоязычный heartbeat вида `OpenCode активен: ...`, если есть активные descendant tools, assistant messages или свежие обновления дочерних сессий.
- Периодически заново объявляет synthetic-статус, чтобы Zed мог вернуть индикацию после reconnect/re-render, если UI потерял строку прогресса.
- Помечает статус как `failed`, если assistant-сообщение долго не обновляется и при этом нет активных tools: это помогает отличить зависший provider/model stream от живой работы.
- Не подставляет raw `session.title` в synthetic heartbeat: заголовки дочерних сессий OpenCode могут быть на английском, но wrapper оставляет их только в логах для диагностики.
- Помечает synthetic-статус как `failed`, если OpenCode остановился после assistant-сообщения без финального текстового отчёта, например после provider interruption или `finish: unknown`.
- Сериализует почти одновременные старты ACP, чтобы снизить риск `database is locked` на SQLite-базе OpenCode.
- Помечает синтетический heartbeat как `failed` после `session/cancel`, чтобы Zed не подавал ложный сигнал "готово" и не оставлял старый прогресс видимым, пока задача перезапускается.
- Продлевает status-monitor после `OPENCODE_ACP_WATCH_STATUS_MAX_SEC`, если OpenCode DB всё ещё показывает активность, чтобы длинные живые задачи не теряли индикацию.
- Закрывает частый случай: родительская задача выглядит старой, но `oracle`, `look_at`, `Sisyphus-Junior` или другие дочерние агенты ещё работают.

## Требования

- Zed с custom ACP agent server.
- Локально установленный OpenCode.
- Python 3.10+.
- Локальная SQLite-база OpenCode, обычно `~/.local/share/opencode/opencode.db`.

Сторонние Python-пакеты не нужны.

## Установка

```sh
git clone https://github.com/shumkiiv/zed-opencode-acp-watch.git
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

После изменения обёртки или настроек Zed нужно перезапустить Zed/OpenCode agent session. Уже запущенные ACP-сессии остаются на старом коде и старом окружении.

## Настройки

| Переменная | По умолчанию | Значение |
| --- | --- | --- |
| `OPENCODE_ACP_WATCH_REAL` | `~/.opencode/bin/opencode` | Настоящий исполняемый файл OpenCode. |
| `OPENCODE_ACP_WATCH_DB` | `~/.local/share/opencode/opencode.db` | SQLite-база OpenCode. |
| `OPENCODE_ACP_WATCH_LOG` | `~/.local/state/zed-opencode-acp-watch/opencode-acp-watch.log` | JSONL-лог обёртки. |
| `OPENCODE_ACP_WATCH_START_LOCK` | `~/.local/state/zed-opencode-acp-watch/opencode-acp-start.lock` | Файловый lock для сериализации начального запуска `opencode acp`. |
| `OPENCODE_ACP_WATCH_START_LOCK_TIMEOUT_SEC` | `15` | Сколько второй старт ждёт startup-lock. |
| `OPENCODE_ACP_WATCH_START_LOCK_HOLD_SEC` | `5` | Сколько первый старт держит lock, пока OpenCode инициализируется. |
| `OPENCODE_ACP_WATCH_HOLD` | `0` | Неблокирующий режим. Старый режим удержания можно включить через `1`. |
| `OPENCODE_ACP_WATCH_POLL_SEC` | `2` | Частота опроса, когда активность видна. |
| `OPENCODE_ACP_WATCH_PREFLIGHT` | `1` | Показывать стартовый статус ресурсов и локальной очереди перед prompt. |
| `OPENCODE_ACP_WATCH_PREFLIGHT_DB_TIMEOUT_SEC` | `0.5` | Максимальное ожидание короткого read-only запроса к OpenCode DB для preflight. |
| `OPENCODE_ACP_WATCH_CONTEXT_WARN` | `1` | Добавлять в preflight предупреждение, если текущая сессия стала тяжёлой по контексту. |
| `OPENCODE_ACP_WATCH_CONTEXT_FILES` | `AI_CONTEXT.md:AGENT_CONTEXT.md:HANDOFF.md:STATUS.md:NEXT_STEPS.md:.ai/context.md:.ai/handoff.md:docs/AI_CONTEXT.md` | Короткие handoff-файлы, которые wrapper ищет в рабочей директории сессии. |
| `OPENCODE_ACP_WATCH_CONTEXT_INPUT_WARN_TOKENS` / `OPENCODE_ACP_WATCH_CONTEXT_INPUT_HEAVY_TOKENS` | `3000000` / `8000000` | Пороги по суммарным input tokens в дереве сессии. |
| `OPENCODE_ACP_WATCH_CONTEXT_PART_WARN_COUNT` / `OPENCODE_ACP_WATCH_CONTEXT_PART_HEAVY_COUNT` | `600` / `1500` | Пороги по числу parts в дереве сессии. |
| `OPENCODE_ACP_WATCH_CONTEXT_TOOL_WARN_COUNT` / `OPENCODE_ACP_WATCH_CONTEXT_TOOL_HEAVY_COUNT` | `120` / `300` | Пороги по числу tool parts в дереве сессии. |
| `OPENCODE_ACP_WATCH_CONTEXT_MESSAGE_WARN_COUNT` / `OPENCODE_ACP_WATCH_CONTEXT_MESSAGE_HEAVY_COUNT` | `160` / `400` | Пороги по числу сообщений в дереве сессии. |
| `OPENCODE_ACP_WATCH_CONTEXT_AGE_WARN_SEC` | `21600` | Предупреждающий порог по возрасту дерева сессии: 6 часов. |
| `OPENCODE_ACP_WATCH_ETA_STATS` | `1` | Записывать статистику точности ETA. |
| `OPENCODE_ACP_WATCH_ETA_STATS_PATH` | `~/.local/state/zed-opencode-acp-watch/opencode-acp-watch-eta.jsonl` | JSONL-файл с прогнозом, фактической длительностью и признаком попадания в диапазон. |
| `OPENCODE_ACP_WATCH_ACTIVE_WINDOW_SEC` | `1800` | Окно для активных `running`/`pending` tools и незавершённых assistant messages. |
| `OPENCODE_ACP_WATCH_STATUS_RECENT_WINDOW_SEC` | `120` | Окно для свежей активности дочерних session/part. |
| `OPENCODE_ACP_WATCH_STATUS_MAX_SEC` | равно active window | Максимальная жизнь status-monitor для одного prompt. |
| `OPENCODE_ACP_WATCH_STATUS_IDLE_POLL_SEC` | `10` | Частота опроса после старта, если активность пока не видна. |
| `OPENCODE_ACP_WATCH_STATUS_REANNOUNCE_SEC` | `60` | Как часто при живой активности заново отправлять полноценный synthetic `tool_call`, чтобы восстановить потерянную строку статуса в Zed. `0` отключает. |
| `OPENCODE_ACP_WATCH_STALE_ASSISTANT_SEC` | `600` | Через сколько секунд без обновлений незавершённого assistant-сообщения и без активных tools считать stream зависшим. `0` отключает. |
| `OPENCODE_ACP_WATCH_CANCEL_GRACE_SEC` | `30` | Сколько держать статус после `session/cancel`, пока обёртка проверяет, продолжает ли OpenCode писать активность сессии. |

## Диагностика

```sh
./scripts/diagnose.sh
```

Скрипт показывает свежие сессии, `running`/`pending` tools и время изменения DB/логов OpenCode. Это полезно, когда Zed выглядит пустым, но OpenCode продолжает двигать дочерние сессии.

## Замечания

Обёртка не меняет OpenCode-сессии, не убивает процессы и не редактирует проекты. Она только читает базу OpenCode и отправляет статусные ACP-обновления в Zed.

Preflight-статус не знает внешнюю очередь провайдера модели. Он даёт локальную оценку по `/proc/loadavg`, `/proc/meminfo`, списку процессов и короткому read-only запросу к SQLite-базе OpenCode. Оценка также учитывает число параллельных ACP-сессий и открытые todo в дереве текущей сессии. Обычно это дешевле одного обычного heartbeat-опроса; если база занята, запрос ограничен таймаутом `OPENCODE_ACP_WATCH_PREFLIGHT_DB_TIMEOUT_SEC`.

ETA показывается грубыми диапазонами: `до 1 мин`, `1-3 мин`, `3-10 мин`, `10+ мин`. После локальной калибровки прогноз стал консервативнее: чистая машина начинается с `1-3 мин`, а активные tools, открытые todo или несколько ACP-сессий поднимают оценку до `3-10 мин` или `10+ мин`. После завершения, отмены, таймаута или остановки monitor в `OPENCODE_ACP_WATCH_ETA_STATS_PATH` добавляется строка с `eta_label`, фактическим `elapsed_sec`, исходом, `eta_hit` и снимком ресурсов. Эта история нужна для настройки порогов под конкретную машину и проекты.

Проверка контекста не сжимает и не удаляет историю OpenCode. Она только предупреждает, что текущую сессию лучше завершить, обновить короткий handoff-файл и продолжить работу в новой сессии. Если в рабочей директории есть `AI_CONTEXT.md` или другой файл из `OPENCODE_ACP_WATCH_CONTEXT_FILES`, wrapper покажет его имя в предупреждении.

После `session/cancel` от Zed status-monitor не закрывает synthetic-статус сразу. Он ждёт `OPENCODE_ACP_WATCH_CANCEL_GRACE_SEC` и проверяет, появились ли в OpenCode новые обновления session, part или message после этого окна. Если работа продолжает двигаться, статус остаётся `in_progress`; если нет, закрывается как отменённый.

Если Zed потерял видимую строку synthetic-статуса, обычные `tool_call_update` могут быть не видны. Поэтому при живой активности wrapper раз в `OPENCODE_ACP_WATCH_STATUS_REANNOUNCE_SEC` повторно отправляет полноценный synthetic `tool_call` с тем же `toolCallId`.

Если provider/model stream завис и OpenCode оставил незавершённое assistant-сообщение без новых parts/tools, wrapper закрывает synthetic-статус как `failed` после `OPENCODE_ACP_WATCH_STALE_ASSISTANT_SEC`. Он не отправляет новый prompt автоматически и не отменяет процесс: решение о новом запросе остаётся за пользователем.

Старые строки `running` в базе OpenCode могут быть stale. Считать задачу живой стоит только если продолжают обновляться сама сессия, дочерние сессии, parts, WAL-файл или лог OpenCode.
