import '../../../core/models/board_role.dart';
import '../../../core/ranking/rank.dart';
import '../domain/board_model.dart';
import '../domain/board_session.dart';

const String _blueHex = '#2D68F5';
const String _greenHex = '#13804F';
const String _violetHex = '#7C4DEB';
const String _pinkHex = '#D23A6E';
const String _amberHex = '#F2A516';

final DateTime demoReferenceTime = DateTime.utc(2026, 1, 15, 12);

abstract final class DemoIds {
  static const String board = 'b-launch';
  static const String elena = 'u-elena';
  static const String maxim = 'u-maxim';
  static const String anya = 'u-anya';
  static const String backlog = 'col-backlog';
  static const String inProgress = 'col-progress';
  static const String review = 'col-review';
  static const String done = 'col-done';
  static const String handshakeCard = 'c-handshake';
  static const String rankCard = 'c-rank';
  static const String readOnlyCard = 'c-read-only';
  static const String syncStateCard = 'c-sync-state';
}

class _Seed {
  const _Seed(
    this.id,
    this.title, {
    this.author = DemoIds.elena,
    this.description = '',
    this.version = 1,
    this.age = const Duration(days: 2),
    this.updatedAge,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final int version;
  final Duration age;
  final Duration? updatedAge;
}

const String _handshakeDescription =
    'Клиент отправляет hello с last_seq. Если журнал покрывает пропуск — '
    'сервер шлёт sync.delta, иначе sync.snapshot.\n\n'
    'До sync.ready никаких операций. Потом rebase очереди и отправка.';

const Map<String, List<_Seed>> _seeds = <String, List<_Seed>>{
  DemoIds.backlog: <_Seed>[
    _Seed('c-rate-limit', 'Rate limit на логин: 5 попыток в минуту'),
    _Seed(
      'c-metrics',
      'Метрики Prometheus: ops_total, ws_closed_total',
      author: DemoIds.maxim,
    ),
    _Seed('c-load-test', 'Load test: 50 клиентов, 20 оп/с'),
    _Seed(
      'c-shutdown',
      'Graceful shutdown с кодом 1001',
      author: DemoIds.maxim,
    ),
    _Seed('c-invite-ttl', 'Срок жизни инвайт-ссылки', author: DemoIds.anya),
    _Seed('c-audit', 'Журнал действий участников'),
  ],
  DemoIds.inProgress: <_Seed>[
    _Seed(
      DemoIds.handshakeCard,
      'Handshake: last_seq → дельта или снапшот',
      author: DemoIds.maxim,
      description: _handshakeDescription,
      version: 14,
      age: Duration(days: 1),
      updatedAge: Duration(minutes: 40),
    ),
    _Seed(
      DemoIds.rankCard,
      'Fractional indexing для rank',
      author: DemoIds.anya,
      version: 3,
      age: Duration(days: 3),
    ),
    _Seed(
      DemoIds.readOnlyCard,
      'Экран доски только на чтение',
      author: DemoIds.anya,
      description: 'Viewer видит доску без «+» и без перетаскивания.',
      version: 5,
      age: Duration(hours: 5),
    ),
    _Seed(DemoIds.syncStateCard, 'BoardSyncState: confirmed + pending'),
  ],
  DemoIds.review: <_Seed>[
    _Seed(
      'c-refresh',
      'Ротация refresh-токенов и reuse detection',
      author: DemoIds.maxim,
    ),
    _Seed('c-presence', 'Presence в Redis с TTL', author: DemoIds.anya),
    _Seed('c-nack', 'Snackbar с причиной nack'),
  ],
  DemoIds.done: <_Seed>[
    _Seed('c-migrations', 'Миграции с advisory lock', author: DemoIds.maxim),
    _Seed('c-close-codes', 'Коды закрытия 4003/4004'),
    _Seed('c-ci', 'CI: lint + тесты', author: DemoIds.maxim),
    _Seed('c-design', 'Дизайн-система: токены и темы', author: DemoIds.anya),
    _Seed('c-fonts', 'Шрифты в assets вместо google_fonts'),
    _Seed('c-l10n', 'Локализация через ARB', author: DemoIds.anya),
    _Seed('c-schema', 'Схема БД: boards, columns, cards'),
    _Seed('c-processed', 'Таблица processed_ops', author: DemoIds.maxim),
    _Seed('c-jwt', 'Access-токен 15 минут'),
    _Seed('c-redis', 'Канал Redis board:{id}', author: DemoIds.maxim),
    _Seed('c-events', 'GET /events?after_seq', author: DemoIds.anya),
    _Seed('c-roles', 'Роли: владелец, редактор, наблюдатель'),
  ],
};

const List<(String, String, ColumnMarker)> _columns =
    <(String, String, ColumnMarker)>[
      (DemoIds.backlog, 'Бэклог', ColumnMarker.backlog),
      (DemoIds.inProgress, 'В работе', ColumnMarker.inProgress),
      (DemoIds.review, 'Ревью', ColumnMarker.review),
      (DemoIds.done, 'Готово', ColumnMarker.done),
    ];

BoardModel demoBoard({
  BoardRole currentUserRole = BoardRole.editor,
  DateTime? now,
}) {
  final reference = (now ?? demoReferenceTime).toUtc();
  final columnRanks = ranksSequence(_columns.length);
  final columns = <ColumnModel>[
    for (var i = 0; i < _columns.length; i++)
      ColumnModel(
        id: _columns[i].$1,
        title: _columns[i].$2,
        rank: columnRanks[i],
        version: 1,
        marker: _columns[i].$3,
      ),
  ];
  final cards = <CardModel>[];
  for (final entry in _seeds.entries) {
    final ranks = ranksSequence(entry.value.length);
    for (var i = 0; i < entry.value.length; i++) {
      final seed = entry.value[i];
      cards.add(
        CardModel(
          id: seed.id,
          columnId: entry.key,
          title: seed.title,
          description: seed.description,
          rank: ranks[i],
          version: seed.version,
          createdBy: seed.author,
          updatedBy: seed.author,
          createdAt: reference.subtract(seed.age),
          updatedAt: reference.subtract(seed.updatedAge ?? seed.age),
        ),
      );
    }
  }
  return BoardModel(
    id: DemoIds.board,
    title: 'Запуск Cardo 1.0',
    seq: 1284,
    columns: columns,
    cards: cards,
    members: <BoardMember>[
      BoardMember(
        userId: DemoIds.elena,
        name: 'Елена',
        avatarColor: _blueHex,
        role: currentUserRole,
      ),
      const BoardMember(
        userId: DemoIds.maxim,
        name: 'Максим',
        avatarColor: _greenHex,
        role: BoardRole.owner,
      ),
      const BoardMember(
        userId: DemoIds.anya,
        name: 'Аня',
        avatarColor: _violetHex,
        role: BoardRole.editor,
      ),
    ],
  );
}

BoardSnapshot demoBoardSnapshot({
  BoardRole currentUserRole = BoardRole.editor,
  DateTime? now,
}) {
  return BoardSnapshot(
    board: demoBoard(currentUserRole: currentUserRole, now: now),
    currentUser: const CurrentUser(
      userId: DemoIds.elena,
      name: 'Елена',
      email: 'elena@studio.ru',
      avatarColor: _blueHex,
    ),
    boards: const <BoardSummary>[
      BoardSummary(
        id: DemoIds.board,
        title: 'Запуск Cardo 1.0',
        colorHex: _pinkHex,
      ),
      BoardSummary(
        id: 'b-content',
        title: 'Контент-план, ноябрь',
        colorHex: _blueHex,
      ),
      BoardSummary(id: 'b-kitchen', title: 'Ремонт кухни', colorHex: _amberHex),
      BoardSummary(id: 'b-site', title: 'Редизайн сайта', colorHex: _violetHex),
    ],
    presence: BoardPresence(
      onlineUserIds: const <String>[DemoIds.elena, DemoIds.maxim, DemoIds.anya],
      editingByCard: const <String, String>{DemoIds.readOnlyCard: DemoIds.anya},
    ),
  );
}
