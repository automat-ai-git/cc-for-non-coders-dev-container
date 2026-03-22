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

## Chart.js и внешние библиотеки

**Правило:** всегда используй CDN. Контейнер имеет доступ в интернет, и CDN работает как в контейнере, так и при открытии файла локально на компьютере студента.

```html
<!-- ПРАВИЛЬНО — CDN работает везде -->
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>

<!-- НЕПРАВИЛЬНО — абсолютный путь ведёт на корень домена -->
<script src="/assets/chart.min.js"></script>

<!-- НЕПРАВИЛЬНО — относительный путь ломается при скачивании файла -->
<script src="../../../../assets/chart.min.js"></script>
```

Если в файле уже стоит неправильный путь — исправь через sed:
```bash
HTML_FILE="/path/to/dashboard.html"
sed -i 's|src="[^"]*chart[^"]*"|src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"|g' "$HTML_FILE"
```

## Типичные ошибки в консоли браузера

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `404 chart.min.js` | Неправильный путь к Chart.js | Замени на CDN: `cdn.jsdelivr.net/npm/chart.js@4.4.1/...` |
| `Cannot read properties of null (reading 'appendChild')` | Chart.js не загрузился | Следствие ошибки выше, исправь путь к Chart.js |
| `Unexpected token '<'` | JS-файл вернул HTML-страницу 404 | Сервер вернул страницу ошибки вместо файла — исправь путь |
| `SyntaxError: missing ) after argument list` | Ошибка в самом HTML/JS файле | Найди и исправь синтаксическую ошибку в файле |

## Важно

- Сервер **не перезапускается автоматически**. Если контейнер перезапустили — надо запустить снова.
- Изменения в файлах видны **сразу** — достаточно обновить страницу (F5) в браузере.
- Если порт 5500 занят другим процессом — используй другой порт (например 5501) и замени его в URL.
