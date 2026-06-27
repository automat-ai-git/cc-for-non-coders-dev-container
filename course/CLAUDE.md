# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Язык общения

Всегда отвечай по-русски. Все пояснения, комментарии, диалог — на русском языке.

## Project overview

Course materials for "Claude Code: суперсила для НЕпрограммистов" (Season 1) by Automatica. A 5-session Russian-language intensive (Feb 24 — Mar 9, 2026) teaching non-developers to use Claude Code for everyday work automation.

Instructor: Антон Вдовиченко, CEO Automatica (@codegeek).

## Repository structure

- `course-outline.md` — detailed 5-session lesson plans
- `README.md` — project overview
- `assets/` — supplementary materials:
  - `knowledge-base/` — reference files for demos (e.g. invoice-kb.md)
  - `prompts/` — reusable prompt files for session demos
- `sessions/` — organized by session number (`01-setup/` through `05-agent-teams/`), each containing `demo/` subdirectories with self-contained project examples (28 demos total)
- `.claude/skills/` — 24 reusable skills (document generation, design, MCP building, etc.)

## Session demos

Each session folder (`sessions/01-setup/` etc.) contains a `demo/` directory with multiple self-contained example projects. Demos are practical business scenarios: financial dashboards, CRM cleanup, contract comparison, vendor evaluation, SEO audits, NPS analysis, cold outreach
personalization, and more. Some demos include their own `.claude/` config (commands, settings) as teaching examples — see `sessions/04-agents/demo/slash-commands-and-hooks/` for an example.

## Language and writing rules

All content is in Russian. When generating or editing text for this project:

1. Avoid AI-isms: inflated significance, promotional language, rule-of-three, em dash overuse, sycophantic tone, filler phrases
2. Use specific details over vague claims
3. Vary sentence structure naturally
4. Keep a conversational but competent tone — not corporate, not overly casual
5. No emojis in course materials unless explicitly requested

## Course structure (5 sessions, 2 academic hours each)

1. **Installation & first tasks** — setup, file organization, format conversion
2. **Context & skills** — CLAUDE.md, Skills system, slash commands
3. **MCP** — connecting external services (Google Drive, Brave Search, databases)
4. **Agents & subagents** — Task Tool, parallel processing, hooks
5. **Agent Teams** — multi-agent orchestration, n8n integration overview

## Key context

- This repository serves as a working base for real projects, not just course materials
- Session demos are practical templates — adapt them for actual business tasks
- Skills in `.claude/skills/` are ready to use in any project within this environment
- Primary AI provider: GLM-5 (via api.z.ai), with Claude and Ollama as alternatives

## Environment knowledge base

This container has access to a full Docker host infrastructure. Persistent knowledge files in `.claude/memory/`:

- **`environment.md`** — Docker host inventory: containers, network topology, filesystem layout, CLI tools
- **`plane.md`** — Plane v1.3.0 self-hosted: MCP access, 13-container architecture, current projects, skills (lesson-tasks, lesson-cleanup, plane-hybrid), and limitations
- **`network.md`** — network topology: split-tunnel VPN (NL + RF), Telegram webhook routing

All three files are on the persistent volume and survive container rebuilds.

## Помощники-агенты

В сети `localai_default` есть агенты-помощники. Делегировать задачи можно **Гусю (Goose, контейнер `goose`)** и **Пи (Pi, контейнер `pi`)**. **MiMo** (`mimocode`) — помнить, что существует, но без отдельного разрешения пользователя не использовать.

Правила:

- В каждую задачу помощнику вкладывается: **изменения в системе — только с разрешения пользователя** (читать и искать свободно).
- Запускать помощника **фоновым shell** (`run_in_background: true`), чтобы оставаться на связи с пользователем во время работы агента.
- Тяжёлые локальные задачи — по одной во времени (общий GPU-пул).

Полная инструкция: `agent-second-brain/agent-helpers.md`. Краткая памятка в памяти: `agent-helpers-control`.

## Синхронизация файлов для других агентов

При любом изменении файлов в `course/.claude/` (memory или skills) — обязательно копировать обновлённые файлы в зеркало на хосте:

/home/coder/course/.claude/memory/  → первоисточник памяти
/home/coder/workspace/agents/memory/claude/  → зеркало памяти (доступно другим агентам)

/home/coder/course/.claude/skills/  → первоисточник скиллов
/home/coder/workspace/agents/skills/claude/  → зеркало скиллов (доступно другим агентам)

Копировать с сохранением структуры папок. Пример:

```bash
cp -r /home/coder/course/.claude/skills/. /home/coder/workspace/agents/skills/claude/
cp /home/coder/course/.claude/memory/plane.md /home/coder/workspace/agents/memory/claude/plane.md
```

Это гарантирует, что другие агенты (goose и т.д.) видят актуальные версии файлов.
