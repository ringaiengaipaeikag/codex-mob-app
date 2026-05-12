# ACPChat (iOS)

Тонкий iOS-клиент к `acp-router` через WebSocket-bridge. Стиль — docs-like:
плоский transcript без пузырей, моно-теги ролей, HR-делители.

## Требования

- iOS 17+ (SwiftData, `@Observable`, `NavigationSplitView`)
- iOS 26+ опционально (FoundationModels локальный fallback — не реализован)
- macOS хост с acp-router + Tailscale

## Структура

```
ACPChat/
  ACPChatApp.swift           # entry + SwiftData ModelContainer
  Models/
    StoredSession.swift      # @Model router sessionId
    StoredMessage.swift      # @Model роль/speaker/streaming
    Speaker.swift            # SpeakerRegistry (alias→tint)
  Network/
    JSONRPC.swift            # AnyCodable + envelopes
    WebSocketTransport.swift # actor, URLSessionWebSocketTask, TLS bypass
    ACPClient.swift          # @MainActor @Observable, ACP facade
  Views/
    DesignSystem.swift       # токены (цвета, шрифты, DSTag, DSDivider, DSCodeBlock)
    RootView.swift           # NavigationSplitView
    SessionListView.swift    # sidebar
    ChatView.swift           # transcript + input bar
    MessageBubble.swift      # docs-style турн (accent bar + теги + md)
    SpeakerChip.swift        # SPEAKER-тег + имя
    ToolPermissionSheet.swift# session/request_permission sheet
    SettingsView.swift       # bridge URL/token/TLS
```

## Создание Xcode-проекта

SwiftUI iOS App, минимальный SDK iOS 17.0.

```
1. Xcode → File → New → Project
   Template: App, Interface: SwiftUI, Language: Swift
   Storage: SwiftData, Product Name: ACPChat, Bundle id: dev.vrt.acpchat
2. Удалить сгенерированные ContentView.swift, Item.swift, ACPChatApp.swift
3. File → Add Files… → выбрать /ios/ACPChat/ (рекурсивно, Create groups)
4. Target → Signing & Capabilities → добавить:
   - App Sandbox OFF (iPadOS использует entitlements по-другому; нужен
     Outgoing (Client) Connections)
   - Если планируется ATS-bypass для self-signed TLS: Info.plist ключ
     NSAppTransportSecurity → NSAllowsArbitraryLoads=true
     (в рамках Tailscale допустимо; на публичные сети НЕ раскатывать)
5. Build & Run на устройстве в той же tailnet
```

## Запуск bridge на хосте

```bash
export ACP_WS_TOKEN=$(openssl rand -hex 32)
export ACP_WS_PORT=8443
export ACP_WS_BIND=0.0.0.0           # или 100.x.y.z (tailscale IP)
export ACP_WS_TLS_CERT=./ws.crt      # self-signed ок внутри tailnet
export ACP_WS_TLS_KEY=./ws.key
# либо ACP_WS_NO_TLS=1 (тогда ws://)
npm run build
node dist/bridges/acp-websocket-bridge.js
```

Self-signed сертификат:

```bash
openssl req -x509 -newkey rsa:2048 -keyout ws.key -out ws.crt \
  -days 365 -nodes -subj "/CN=$(hostname)"
```

## Настройка в iOS

Открыть Settings (иконка шестерёнки в сайдбаре):

- URL: `wss://100.x.y.z:8443/acp`
- Token: значение `ACP_WS_TOKEN`
- Allow self-signed: ON (внутри tailnet)

Нажать Connect. Индикатор слева в тулбаре: зелёный — online.

## Протокол

iOS клиент говорит с бриджем как обычный ACP-клиент поверх WebSocket:
NDJSON (JSON-RPC 2.0). Каждое WS text-сообщение — один JSON-RPC envelope.

Поддерживаемое клиентом:

- `initialize` (protocolVersion: 1)
- `session/new` → routerSessionId
- `session/load` (lazy-revive на сервере)
- `session/prompt` + streaming через `session/update`
- `session/cancel`

Server-initiated, обрабатываются в клиенте:

- `session/request_permission` → ToolPermissionSheet
- `fs/read_text_file` / `fs/write_text_file` → по дефолту отказ
  (включается когда на клиенте будут реализованы file handlers)

## Безопасность

- Bearer-токен через `Authorization: Bearer` или `?token=`.
- `timingSafeEqual` в bridge.
- Биндинг по умолчанию 127.0.0.1 (on-prem) либо tailnet IP.
- TLS бампаем только для self-signed внутри tailnet.
- Никогда не коммитить `ws.key`, `.env`, tokens.

## Известные ограничения

- Нет on-device LLM (FoundationModels на iOS 26+ — см. ниже).
- `fs/*` server-requests пока отклоняются.
- Терминал (`terminal/create`) не реализован.
- Нет background-доставки стриминга при экранной блокировке.
