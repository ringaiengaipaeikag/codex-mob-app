#!/usr/bin/env bash
# Setup для ACPChat iOS: ставит xcodegen (если нет) и генерирует .xcodeproj.
set -euo pipefail

cd "$(dirname "$0")"

echo "=== ACPChat iOS setup ==="

if ! command -v xcodegen >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew не найден. Установи: https://brew.sh" >&2
        exit 1
    fi
    echo "→ устанавливаю xcodegen через brew…"
    brew install xcodegen
fi

echo "→ генерирую ACPChat.xcodeproj…"
xcodegen generate --spec project.yml

if [ ! -d ACPChat.xcodeproj ]; then
    echo "Генерация не удалась." >&2
    exit 1
fi

echo
echo "=== Готово ==="
echo "  проект: $(pwd)/ACPChat.xcodeproj"
echo
echo "Далее:"
echo "  1. open ACPChat.xcodeproj"
echo "  2. Выбери Team (Signing & Capabilities)"
echo "  3. Подключи iPhone, выбери его в target-селекторе"
echo "  4. ⌘R (Run)"
echo
echo "На Mac-хосте:"
echo "  export ACP_WS_TOKEN=\$(openssl rand -hex 32)"
echo "  export ACP_WS_PORT=8443"
echo "  export ACP_WS_BIND=0.0.0.0  # или твой tailnet IP"
echo "  # self-signed TLS (ок в tailnet):"
echo "  openssl req -x509 -newkey rsa:2048 -keyout ws.key -out ws.crt \\"
echo "    -days 365 -nodes -subj \"/CN=\$(hostname)\""
echo "  export ACP_WS_TLS_CERT=\$(pwd)/ws.crt"
echo "  export ACP_WS_TLS_KEY=\$(pwd)/ws.key"
echo "  npm run build && node dist/bridges/acp-websocket-bridge.js"
echo
echo "В iOS-приложении (Settings):"
echo "  URL:   wss://<tailnet-ip>:8443/acp"
echo "  Token: \$ACP_WS_TOKEN"
echo "  Allow self-signed: ON"
