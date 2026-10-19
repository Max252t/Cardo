# Cardo

[![CI](https://github.com/Max252t/Cardo/actions/workflows/ci.yml/badge.svg)](https://github.com/Max252t/Cardo/actions/workflows/ci.yml)

Мобильный клиент на Flutter для совместной работы над канбан-досками в реальном времени (Trello-lite). Несколько пользователей одновременно двигают и редактируют карточки и видят изменения друг друга без перезагрузки.

В этом репозитории только Flutter-клиент. Сервер (Go / Gin, PostgreSQL, Redis) живёт отдельно.

> **Статус:** каркас проекта. Функциональность в разработке.

## Возможности (MVP)

- Регистрация и вход по email и паролю, прозрачное обновление access-токена.
- Доски с ролями `owner` / `editor` / `viewer`, приглашения по email и инвайт-ссылке.
- Колонки и карточки: создание, редактирование, перемещение drag-and-drop, архивирование.
- Realtime через WebSocket: изменения других участников, presence, индикатор соединения.
- Оптимистичный UI: действия применяются мгновенно, отклонённые сервером операции исчезают с понятным сообщением.
- Офлайн-очередь операций и переподключение с экспоненциальным backoff.

## Как устроена синхронизация

Клиент хранит два слоя состояния доски:

- **confirmed** — состояние, построенное только из событий сервера;
- **pending** — очередь собственных операций, ещё не подтверждённых сервером.

Пользователь видит их композицию:

```dart
BoardModel view(BoardSyncState s) =>
    s.pending.fold(s.confirmed, (board, op) => op.applyTo(board));
```

- Каждое событие сервера несёт монотонный `seq` доски. События применяются строго по порядку, дубликаты отбрасываются, пропуски догружаются через REST.
- Подтверждением операции служит событие с её `op_id`, отказом — `nack` с причиной (`version_conflict`, `forbidden`, `not_found` и т. д.).
- ID новых сущностей генерирует клиент (UUID v7), поэтому повторная отправка очереди не создаёт дубликатов.
- Порядок карточек и колонок задаётся строковым `rank` (fractional indexing). Клиент указывает соседей (`after_id` / `before_id`), итоговый rank вычисляет сервер.
- После переподключения: `hello { last_seq }` → дельта или снапшот → rebase очереди → отправка.

## Стек

| Назначение | Библиотека |
|------------|------------|
| Состояние и DI | Riverpod 3 |
| Модели | freezed |
| REST | dio |
| WebSocket | web_socket_channel |
| Хранение токенов | flutter_secure_storage |
| Drag-and-drop | `LongPressDraggable` + `DragTarget` |

## Структура

```
lib/
├── core/
│   ├── api/            # dio, интерсептор токенов, ошибки
│   ├── auth/           # хранение токенов, сессия
│   ├── realtime/       # WsConnection: reconnect, heartbeat, handshake
│   └── ranking/        # fractional indexing
├── features/
│   ├── auth/
│   ├── boards/         # список досок
│   ├── board/
│   │   ├── domain/     # BoardModel, операции, applyTo
│   │   ├── data/       # BoardSyncNotifier: confirmed + pending
│   │   └── presentation/
│   ├── members/
│   └── presence/
└── main.dart
```

## Запуск

Требования: Flutter 3.47 (stable), Dart 3.13+.

```bash
flutter pub get
```

```bash
flutter run
```

## Проверки

Те же проверки запускаются в CI на каждый push и pull request в `main`:

```bash
dart format --output=none --set-exit-if-changed .
```

```bash
flutter analyze --fatal-infos
```

```bash
flutter test
```

## Git

- Модель ветвления — GitHub Flow: `main` всегда рабочий, изменения через feature-ветки и Pull Request.
- Сообщения коммитов — [Conventional Commits](https://www.conventionalcommits.org/ru/v1.0.0/).

## Лицензия

[MIT](LICENSE)
