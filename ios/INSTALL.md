# ACPChat — Установка на iPhone

TL;DR: у тебя есть Swift-исходники + `project.yml` для xcodegen + `setup.sh`. Нужен Mac с Xcode (бесплатно из Mac App Store). Без Mac на iPhone 17 свою сборку не поставить — Apple требует подпись через Apple Developer identity.

---

## Путь 1 — Mac + Xcode + бесплатный Apple ID (7 дней, но бесплатно)

Подписи хватает на 7 дней, потом приложение «протухает» — открываешь Xcode и снова ⌘R. Для личного использования — норм.

```bash
# Распаковать архив куда удобно
cd ~/Projects/
unzip ACPChat-ios.zip        # создаст папку acpchat-ios/
cd acpchat-ios

# Поставить xcodegen и сгенерить .xcodeproj
./setup.sh
# ↑ установит brew-пакет xcodegen (если нет) и создаст ACPChat.xcodeproj

open ACPChat.xcodeproj
```

В Xcode:

1. Выбрать target **ACPChat** → вкладка **Signing & Capabilities**.
2. **Team**: залогиниться любым Apple ID (`Add Account…`) и выбрать свою Personal Team.
3. **Bundle Identifier**: смени `dev.vrt.acpchat` на что-то уникальное, например `me.<твой-apple-id>.acpchat` — иначе будет конфликт с чужими подписями.
4. Подключить iPhone кабелем. На iPhone: `Settings → General → VPN & Device Management` — доверить developer cert (появится после первого запуска).
5. В Xcode target-селектор сверху — выбрать свой iPhone → **⌘R** (Run).

Первый запуск: iPhone скачает symbols, потом приложение появится на home screen.

## Путь 2 — Apple Developer Account ($99/год) — на 1 год без ⌘R

Всё то же самое, но Team = Apple Developer Program → провижининг не протухает 365 дней. Можно распространять через **TestFlight** (до 100 internal testers без review, до 10k external testers с review).

## Путь 3 — AltStore / Sideloadly (для jailbreak-free sideload)

1. В Xcode собери **Archive** (`Product → Archive`) → `Distribute App → Copy App → копируется .xcarchive`.
2. Из `.xcarchive` вытащи `Products/Applications/ACPChat.app` → зазипуй, переименуй в `ACPChat.ipa`.
3. На Mac: установи [AltServer](https://altstore.io/), на iPhone — AltStore.
4. В AltStore: `+` → выбрать `ACPChat.ipa` → подпишется твоим Apple ID (7 дней, AltServer умеет авто-обновлять подпись когда iPhone в одной сети).

Плюс AltStore: авто-refresh подписи, не надо каждые 7 дней подключать iPhone в Xcode. Минус: AltServer должен крутиться на Mac в той же wifi.

## Путь 4 — jailbroken iPhone

Если iPhone jailbroken — `.ipa` без подписи ставится через Filza/TrollStore/AppSync Unified. Я не буду расписывать детально — зависит от версии iOS/типа jailbreak. `.ipa` всё равно делать на Mac через Xcode archive.

## Путь 5 — GitHub Actions с macOS runner'ом

Если Mac нет физически, но есть Apple Developer аккаунт — можно завести pipeline на GitHub Actions: runner `macos-14`, туда через secrets закидываешь `.p12` cert + `.mobileprovision`, он сам собирает `.ipa` и выкладывает артефактом. Шаблон workflow могу написать отдельно, скажи если надо.

---

## Параллельно — настроить bridge

Приложение без bridge-а — пустая оболочка. Запускай на сервере:

```bash
# На Parrot Security box:
cd acp-router
./ios/cloudflared-setup.sh acp.твой-домен.tld   # один раз
sudo systemctl enable --now cloudflared acp-bridge
```

В iOS Settings:
- **URL**: `wss://acp.твой-домен.tld/acp`
- **Bearer token**: значение `$ACP_WS_TOKEN` с сервера (`/etc/acp-bridge.env`)
- **Allow self-signed TLS**: OFF (CF даёт настоящий сертификат)
- Cloudflare Access (опц.): Client-Id / Client-Secret из Zero Trust → Service Tokens

## На iPhone iOS 26+ есть FoundationModels

Приложение собрано с поддержкой Apple Intelligence on-device как приватного fallback — для запросов, которые не хочется гнать через bridge. Работает только если у тебя включён Apple Intelligence в `Settings → Apple Intelligence & Siri`.

---

## Если что-то не собирается

- **`xcodegen: command not found`** — `brew install xcodegen` (setup.sh пытается сам).
- **`No provisioning profile`** — не забыл выбрать Team? Bundle ID должен быть уникален.
- **`Signing requires a development team`** — тот же пункт, Team = твоя Personal Team.
- **App ставится, но не запускается, iOS ругается на cert** — `Settings → General → VPN & Device Management → Developer App → Trust <твой Apple ID>`.
- **`.ipa` не ставится через AltStore** — проверь что Apple ID в AltStore тот же, что в Xcode на момент архивации.
