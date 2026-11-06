# Cardo

[![CI](https://github.com/Max252t/Cardo/actions/workflows/ci.yml/badge.svg)](https://github.com/Max252t/Cardo/actions/workflows/ci.yml)

Клиент на Flutter для совместной работы над канбан-досками в реальном времени. Несколько человек одновременно двигают и правят карточки и сразу видят изменения друг друга.

В репозитории только клиент. Сервер (Go, PostgreSQL, Redis) живёт отдельно: [Cardo-backend](https://github.com/Max252t/Cardo-backend).

Текущее состояние и список реализованного: [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md).

## Что умеет приложение

- Регистрация, вход, профиль, выход. Access-токен хранится в памяти, refresh-токен в защищённом хранилище.
- Список досок и создание доски.
- Доска с колонками и карточками: создание, правка, перетаскивание, архив.
- Роли `owner`, `editor`, `viewer`, участники доски, инвайт-ссылки и переход по ним.
- Настройки доски: переименование, удаление, выход.
- Синхронизация по WebSocket: чужие изменения без перезагрузки, присутствие участников, индикатор соединения, переподключение, очередь неподтверждённых операций и сообщения об отклонённых.
- Русский и английский интерфейс, светлая и тёмная тема.

## Требования

- Flutter 3.47 (stable), Dart 3.13.
- Windows: включённый Developer Mode (`start ms-settings:developers`) и компонент Visual Studio «C++ ATL». Он нужен для `flutter_secure_storage`.
- Для Android и iOS: обычные инструменты Flutter для платформы.

Зависимости:

```bash
flutter pub get
```

## Адрес сервера

Адрес передаётся через `--dart-define` с ключом `API_BASE_URL` и в коде не хранится.

1. Скопируйте `env/example.json` в `env/local.json`. Файл `env/local.json` игнорируется git.
2. Впишите адрес сервера в `API_BASE_URL`:

```json
{"API_BASE_URL": "http://localhost:8080"}
```

Адрес без схемы `http` или `https`, с параметрами (`?`), фрагментом (`#`) или логином с паролем считается неверным.

| Где запущено приложение | Адрес |
|---|---|
| Windows, macOS, Linux | `http://localhost:8080` |
| Android-эмулятор | `http://10.0.2.2:8080` |
| iOS-симулятор | `http://localhost:8080` |
| Реальный сервер | `https://...` |

Порт `8080` приходит из `docker-compose.yml` бэкенда. WebSocket-адрес строится из того же значения: `http` превращается в `ws`, `https` в `wss`.

Правила для HTTP заданы настройками платформ:

- debug и profile на Android разрешают HTTP только для `localhost`, `127.0.0.1` и `10.0.2.2` (`android/app/src/main/res/xml/network_security_config.xml`);
- debug на iOS разрешает HTTP только для локальной сети (`NSAllowsLocalNetworking` в `ios/Runner/Info-Debug.plist`);
- release требует HTTPS.

## Запуск

```bash
flutter run -d windows --dart-define-from-file=env/local.json
```

Вместо `windows` подставьте нужное устройство (`flutter devices`).

Без адреса сервера (пустой или неверный `API_BASE_URL`) откроется экран конфигурации. В debug-сборке на нём есть кнопка демо-доски, которая работает на встроенном фейковом сервере без сети.

### Запуск сервера

Инструкция лежит в репозитории [Cardo-backend](https://github.com/Max252t/Cardo-backend). Коротко:

```bash
git clone https://github.com/Max252t/Cardo-backend.git
cd Cardo-backend
docker compose up --build
```

Сервер откроется на `http://localhost:8080`.

## Проверки

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --fatal-infos
flutter test --no-pub
```

После правки ARB-файлов в `lib/l10n/` перегенерируйте локализацию:

```bash
flutter gen-l10n
```

Флаг `--no-pub` отключает неявный `pub get` перед командой: он обращается к сети и может надолго зависать. Выполните `flutter pub get` один раз при смене зависимостей, дальше запускайте с `--no-pub`. CI запускает те же проверки на каждый push и pull request.

Строки интерфейса хранятся в `lib/l10n/app_ru.arb` (шаблон) и `lib/l10n/app_en.arb`. Тест следит, чтобы ключи и плейсхолдеры в двух файлах совпадали.

## Структура проекта

```
lib/
├── app/          # роутер, корневой виджет, экран конфигурации
├── core/         # config, network, realtime, ranking, result, models, invite, equality
├── features/
│   ├── auth/            # вход, регистрация, профиль, сессия
│   ├── boards/          # список досок
│   ├── board/           # доска, карточки, синхронизация
│   ├── board_settings/  # переименование, удаление, выход с доски
│   ├── members/         # участники и роли
│   ├── invites/         # инвайт-ссылки
│   └── design_preview/  # просмотр дизайн-системы (debug)
├── shared/       # общие виджеты, провайдеры, время, ошибки, язык
├── theme/        # токены дизайн-системы и темы
├── l10n/         # ARB-файлы и сгенерированные классы
└── main.dart
```

Фича делится на слои:

- `domain` содержит чистый Dart, без Flutter и без зависимостей от `data`;
- `data` содержит работу с сетью и хранилищем, без Flutter UI, Riverpod и `dart:ui`;
- `presentation` содержит экраны, виджеты и контроллеры на Riverpod.

Правила чистой архитектуры закреплены тестами в `test/policy/`:

- `layer_boundaries_test.dart` проверяет, какие слои на что могут ссылаться;
- `realtime_boundaries_test.dart` проверяет границы realtime-кода;
- `no_raw_values_test.dart` запрещает сырые цвета, размеры и длительности вне `lib/theme/`;
- `no_hardcoded_endpoints_test.dart` запрещает адреса сервера в коде;
- `no_hardcoded_locale_test.dart` запрещает жёстко заданный язык.

## Git

- Модель ветвления — Git Flow: `main` для релизов, `develop` для разработки, фичи в `feature/*` от `develop`.
- Сообщения коммитов — [Conventional Commits](https://www.conventionalcommits.org/ru/v1.0.0/).

## Лицензия

[MIT](LICENSE)
