FROM ubuntu:26.04

ARG CODE_SERVER_VERSION=4.134.0
# Node 24 ("Krypton") is the current LTS. Node 26 exists but only becomes LTS in
# October 2026 — don't move the cohort onto it before then.
ARG NODE_VERSION=24
# Pinned: an unpinned install silently moves the whole cohort to a new Claude Code
# on every rebuild. Bump deliberately, then rebuild and smoke-test one container.
ARG CLAUDE_CODE_VERSION=2.1.241
# Same reasoning — the upstream installer always grabs the newest release.
ARG FILEBROWSER_VERSION=2.63.23

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# System packages + LibreOffice (for docx/pptx/xlsx conversion) + FFmpeg (for GIF/video)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    sudo \
    locales \
    python3-pip \
    jq \
    unzip \
    dumb-init \
    ffmpeg \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    tmux \
    fonts-liberation \
    fonts-dejavu-core \
    pandoc \
    poppler-utils \
    qpdf \
    tesseract-ocr \
    tesseract-ocr-rus \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3 /usr/bin/python

# Node.js 24 LTS (manual repo setup — NodeSource setup scripts deprecated)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# code-server (VS Code in browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=${CODE_SERVER_VERSION}

# File Browser — lightweight web file manager for demos.
# Installed from the release tarball rather than get.sh, which always takes the
# newest release. TARGETARCH is supplied by BuildKit (amd64 on the VPS, arm64 on Macs).
ARG TARGETARCH
RUN curl -fsSL "https://github.com/filebrowser/filebrowser/releases/download/v${FILEBROWSER_VERSION}/linux-${TARGETARCH}-filebrowser.tar.gz" \
    | tar -xz -C /usr/local/bin filebrowser \
    && chmod +x /usr/local/bin/filebrowser

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# npm packages used by Skills (docx/pptx generation, web bundling)
RUN npm install -g docx pptxgenjs parcel @parcel/config-default html-inline

# Python packages used by Skills
RUN pip3 install --break-system-packages --no-cache-dir \
    pypdf \
    python-pptx \
    python-docx \
    openpyxl \
    pillow \
    numpy \
    pandas \
    matplotlib \
    cairosvg \
    requests \
    lxml \
    imageio \
    imageio-ffmpeg \
    anthropic \
    mcp \
    pdfplumber \
    reportlab \
    pdf2image \
    "markitdown[pptx]" \
    pytesseract \
    playwright \
    defusedxml \
    PyYAML

# Create user
RUN useradd -m -s /bin/bash -G sudo coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

USER coder
WORKDIR /home/coder

# Git defaults (Claude Code uses git for diffs and commits)
RUN git config --global user.name "Course Student" \
    && git config --global user.email "student@course.local" \
    && git config --global init.defaultBranch main

# VS Code extensions: preview HTML, PDF, Excel, images inside the editor
RUN code-server --install-extension ms-vscode.live-server \
    && code-server --install-extension tomoki1207.pdf \
    && code-server --install-extension GrapeCity.gc-excelviewer \
    && code-server --install-extension hediet.vscode-drawio \
    || true

# Playwright: install Chromium browser + system deps
RUN playwright install --with-deps chromium

# code-server settings
RUN mkdir -p /home/coder/.local/share/code-server/User
COPY --chown=coder:coder code-server-settings.json /home/coder/.local/share/code-server/User/settings.json

# Course materials: copy to .course-image (pristine) and course (working dir).
# When a volume is mounted at /home/coder/course/, entrypoint.sh copies
# from .course-image on first run, so student work persists across restarts.
COPY --chown=coder:coder course/ /home/coder/.course-image/
COPY --chown=coder:coder course/ /home/coder/course/

# Claude Code config
RUN mkdir -p /home/coder/.claude
COPY --chown=coder:coder claude-settings.json /home/coder/.claude/settings.json

# Skills — available globally (~/.claude/skills/) and in course root (course/.claude/skills/)
COPY --chown=coder:coder skills/ /home/coder/.claude/skills/
COPY --chown=coder:coder skills/ /home/coder/.course-image/.claude/skills/
COPY --chown=coder:coder skills/ /home/coder/course/.claude/skills/

# File Browser config (accessed via auth gateway at /files/)
RUN mkdir -p /home/coder/.config/filebrowser
RUN filebrowser config init --database /home/coder/.config/filebrowser/filebrowser.db \
    --root /home/coder/course \
    --address 127.0.0.1 \
    --port 9090 \
    --baseurl /files \
    --auth.method=noauth \
    --branding.name="Claude Code: Файлы курса" \
    && filebrowser users add admin admin-noauth-dummy --perm.admin --database /home/coder/.config/filebrowser/filebrowser.db

# Auth gateway (single entry point with branded login)
COPY --chown=coder:coder auth-gateway.py /home/coder/auth-gateway.py
COPY --chown=coder:coder login.html /home/coder/login.html

# Entrypoint
COPY --chown=coder:coder entrypoint.sh /home/coder/entrypoint.sh

# Chart.js offline (used by financial-dashboard and quarterly-presentation demos)
RUN mkdir -p /home/coder/course/assets \
    && curl -fsSL https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js \
    -o /home/coder/course/assets/chart.min.js || true

# Pre-cache MCP packages (avoid 25-50 students downloading simultaneously)
RUN npx -y @anthropic-ai/mcp-server-filesystem --help 2>/dev/null || true

# Port 8080 = auth gateway (single entry point)
EXPOSE 8080

# Node.js 24 no longer auto-resolves global modules; scripts need NODE_PATH
ENV NODE_PATH="/usr/lib/node_modules"
ENV PASSWORD=""
ENV ANTHROPIC_AUTH_TOKEN=""
ENV ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
ENV ANTHROPIC_DEFAULT_OPUS_MODEL="GLM-5.3"
ENV ANTHROPIC_DEFAULT_SONNET_MODEL="GLM-5.3"
# Haiku slot carries background work (session titles, small classifications), so it
# stays on the cheap model. z.ai currently serves GLM-4.5-Air requests with glm-4.7.
ENV ANTHROPIC_DEFAULT_HAIKU_MODEL="GLM-4.5-Air"
ENV API_TIMEOUT_MS="3000000"
ENV ANTHROPIC_AUTH_TOKEN_BACKUP=""

# Agent Teams (session 5) — experimental, off by default in Claude Code.
# Without it no team is created and Claude never spawns teammates.
ENV CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"

ENTRYPOINT ["dumb-init", "--", "/home/coder/entrypoint.sh"]
