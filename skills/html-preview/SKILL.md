---
name: html-preview
description: Launch a local HTTP server to preview HTML homework files in the browser. Use when the user wants to open, view, or check an HTML file in the browser — including dashboards, reports, and web pages created during course exercises. Handles Chart.js and other local asset paths automatically.
---

# HTML Preview — просмотр HTML-файлов в браузере

Используй этот навык, когда студент хочет открыть HTML-файл в браузере для проверки домашней работы или демо.

## Как работает доступ к серверу

Контейнер открывает порты через прокси code-server. Порт `5500` доступен по адресу:
```
https://<домен>/ide/proxy/5500/
```

Файлы курса находятся в `/home/coder/course/`. Если сервер запущен из этой папки, то файл по пути `sessions/01-setup/demo/financial-dashboard/dashboard.html` будет доступен по ссылке:
```
https://<домен>/ide/proxy/5500/sessions/01-setup/demo/financial-dashboard/dashboard.html
```

## Шаг 1 — Проверить, не запущен ли уже сервер

```bash
pgrep -a python3 | grep "http.server"
```

Если сервер уже запущен — сообщи пользователю текущий URL и не запускай новый.

## Шаг 2 — Запустить сервер в фоне (tmux)

Запускай **только через tmux**, иначе сервер остановится вместе с командой:

```bash
tmux new-session -d -s preview-server -x 200 -y 50 \
  "cd /home/coder/course && python3 -m http.server 5500"
```

Проверь, что сервер запустился:
```bash
sleep 1 && curl -s -o /dev/null -w "%{http_code}" http://localhost:5500/
```

Ожидаемый ответ: `200` или `301`. Если `000` — сервер не запустился, попробуй снова.

## Шаг 3 — Сообщить пользователю ссылку

Определи реальный домен из переменной окружения или из известных путей:
```bash
echo "${VSCODE_PROXY_URI:-неизвестно}"
```

Если домен неизвестен — попроси пользователя посмотреть адресную строку браузера и взять только домен (например `cc.example.com`), затем составь ссылку самостоятельно.

Сообщи пользователю:
```
Сервер запущен. Открой в браузере:
https://<домен>/ide/proxy/5500/<путь-к-файлу>

Например:
https://cc.example.com/ide/proxy/5500/sessions/01-setup/demo/financial-dashboard/dashboard.html
```

## Остановить сервер

```bash
tmux kill-session -t preview-server 2>/dev/null || true
```

Или найти и убить процесс вручную:
```bash
pkill -f "http.server 5500" || true
```

## Исправление путей к Chart.js и другим ассетам

Chart.js и другие ассеты курса лежат в `/home/coder/course/assets/`.

**Проблема:** HTML-файлы иногда ссылаются на CDN (`cdn.jsdelivr.net`) или используют абсолютный путь `/assets/...`. Ни то, ни другое не работает внутри контейнера.

**Правило:** всегда используй **относительный путь** от HTML-файла до папки `assets/`.

Для файла на глубине 4 уровня (`sessions/NN/demo/project/file.html`):
```html
<!-- НЕПРАВИЛЬНО — CDN недоступен -->
<script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>

<!-- НЕПРАВИЛЬНО — абсолютный путь ведёт на корень домена, а не курса -->
<script src="/assets/chart.min.js"></script>

<!-- ПРАВИЛЬНО — относительный путь -->
<script src="../../../../assets/chart.min.js"></script>
```

Формула подсчёта `../`: считай, сколько папок между HTML-файлом и `course/`, и столько раз пиши `../`.

### Автоисправление через sed

Если нужно заменить CDN на локальный файл:
```bash
HTML_FILE="/home/coder/course/sessions/01-setup/demo/financial-dashboard/dashboard.html"
sed -i 's|https://cdn.jsdelivr.net/npm/chart.js[^"]*|../../../../assets/chart.min.js|g' "$HTML_FILE"
```

Проверь результат:
```bash
grep -n "chart" "$HTML_FILE"
```

## Типичные ошибки в консоли браузера

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `404 chart.min.js` | Неправильный путь к Chart.js | Исправь путь на относительный `../../../../assets/chart.min.js` |
| `Cannot read properties of null (reading 'appendChild')` | Chart.js не загрузился | Следствие ошибки выше, исправь путь |
| `Unexpected token '<'` | JS-файл вернул HTML-страницу 404 | Тот же путь — сервер вернул страницу ошибки вместо файла |
| `SyntaxError: missing ) after argument list` | Ошибка в самом HTML/JS файле | Найди и исправь синтаксическую ошибку в файле |

## Важно

- Сервер **не перезапускается автоматически**. Если контейнер перезапустили — надо запустить снова.
- Изменения в файлах видны **сразу** — достаточно обновить страницу (F5) в браузере.
- Если порт 5500 занят другим процессом — используй другой порт (например 5501) и замени его в URL.
