// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Cardo';

  @override
  String get brandName => 'cardo';

  @override
  String get logoSemanticLabel => 'Логотип cardo';

  @override
  String get connectionConnected => 'В сети';

  @override
  String get connectionSyncing => 'Синхронизация';

  @override
  String get connectionReconnecting => 'Переподключение';

  @override
  String connectionReconnectingIn(int seconds) {
    return 'Переподключение · $seconds с';
  }

  @override
  String get connectionOffline => 'Офлайн';

  @override
  String connectionSemanticLabel(String status) {
    return 'Соединение: $status';
  }

  @override
  String avatarOverflow(int count) {
    return '+$count';
  }

  @override
  String get cardDropPlaceholder => 'Место для карточки';

  @override
  String get roleOwner => 'Владелец';

  @override
  String get roleEditor => 'Редактор';

  @override
  String get roleViewer => 'Наблюдатель';

  @override
  String roleSemanticLabel(String role) {
    return 'Роль: $role';
  }

  @override
  String get cardDescription => 'Описание';

  @override
  String get cardPending => 'В очереди';

  @override
  String get cardDragging => 'Перемещение';

  @override
  String get cardRejected => 'Не применено';

  @override
  String cardEditingBy(String name) {
    return '$name редактирует';
  }

  @override
  String cardUpdatedBy(String name) {
    return 'Изменил $name';
  }

  @override
  String presenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника на доске',
      many: '$count участников на доске',
      few: '$count участника на доске',
      one: '$count участник на доске',
    );
    return '$_temp0';
  }

  @override
  String pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изменения ждут',
      many: '$count изменений ждут',
      few: '$count изменения ждут',
      one: '$count изменение ждёт',
    );
    return '$_temp0';
  }

  @override
  String get previewTitle => 'Дизайн-система';

  @override
  String get previewLightTheme => 'Светлая тема';

  @override
  String get previewDarkTheme => 'Тёмная тема';

  @override
  String get previewSectionLogo => 'Логотип';

  @override
  String get previewSectionCards => 'Карточка: состояния';

  @override
  String get previewSectionCardsDense => 'Карточка: desktop';

  @override
  String get previewSectionConnection => 'Соединение';

  @override
  String get previewSectionRoles => 'Роли и присутствие';

  @override
  String get previewSectionButtons => 'Кнопки и уведомления';

  @override
  String get previewCardConfirmed => 'Fractional indexing для rank';

  @override
  String get previewCardPending => 'Presence в Redis с TTL';

  @override
  String get previewCardDragging => 'Тест сходимости: 1000 операций';

  @override
  String get previewCardRejected => 'Коды закрытия 4003/4004';

  @override
  String get previewCardEditing => 'Экран доски только на чтение';

  @override
  String get previewNameAnya => 'Аня';

  @override
  String get previewNameMaxim => 'Максим';

  @override
  String get previewNameElena => 'Елена';

  @override
  String get previewNameOlga => 'Ольга';

  @override
  String get previewNameDmitry => 'Дмитрий';

  @override
  String get previewRejectReason => 'Карточку уже переместил Максим';

  @override
  String get previewNewBoard => 'Новая доска';

  @override
  String get previewInvite => 'Пригласить';

  @override
  String get previewCancel => 'Отменить';

  @override
  String get previewOverwrite => 'Перезаписать';

  @override
  String get previewEmailHint => 'Email коллеги';

  @override
  String get previewShowSnackbar => 'Показать уведомление';

  @override
  String get previewSnackbarMessage =>
      'Карточку уже переместил Максим — она осталась в «Ревью»';

  @override
  String get previewSnackbarAction => 'Понятно';

  @override
  String get boardBack => 'Назад к доскам';

  @override
  String get boardMenu => 'Меню доски';

  @override
  String get boardAddCard => 'Добавить карточку';

  @override
  String get boardAddColumn => 'Колонка';

  @override
  String get boardAddColumnSemantic => 'Добавить колонку';

  @override
  String boardColumnSemantic(String title) {
    return 'Колонка «$title»';
  }

  @override
  String boardTabSemantic(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '$count карточка',
    );
    return '$title, $_temp0';
  }

  @override
  String boardPageIndicator(int index, int total) {
    return 'Колонка $index из $total';
  }

  @override
  String boardSeq(int seq) {
    final intl.NumberFormat seqNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String seqString = seqNumberFormat.format(seq);

    return 'seq $seqString';
  }

  @override
  String get boardSearch => 'Поиск';

  @override
  String get boardSidebarBoards => 'Доски';

  @override
  String get boardNewBoard => 'Новая доска';

  @override
  String get boardMembers => 'Участники';

  @override
  String get boardInvite => 'Пригласить';

  @override
  String get boardComingSoon => 'Появится в следующих версиях';

  @override
  String boardViewerBanner(String owner) {
    return 'Вы наблюдатель: можно смотреть, но не менять. Права выдаёт владелец — $owner.';
  }

  @override
  String get boardViewerBannerNoOwner =>
      'Вы наблюдатель: можно смотреть, но не менять.';

  @override
  String get cardDragHint => 'Удерживайте, чтобы перетащить';

  @override
  String cardMoveTo(String column) {
    return 'Переместить в «$column»';
  }

  @override
  String get cardPanelArchive => 'В архив';

  @override
  String get cardPanelClose => 'Закрыть';

  @override
  String cardPanelCreatedBy(String name) {
    return 'Создал $name';
  }

  @override
  String cardPanelVersion(int version) {
    return 'v$version';
  }

  @override
  String get cardPanelDescriptionHint => 'Добавьте описание';

  @override
  String get cardPanelSave => 'Сохранить';

  @override
  String get cardPanelMove => 'Переместить';

  @override
  String cardPanelSemantic(String title) {
    return 'Карточка «$title»';
  }

  @override
  String get cardPreviewNoDescription => 'Описания пока нет';

  @override
  String get addCardTitle => 'Новая карточка';

  @override
  String get addCardHint => 'Заголовок карточки';

  @override
  String get addCardSubmit => 'Добавить';

  @override
  String get addCardCancel => 'Отменить';

  @override
  String get nackForbidden => 'Нет прав на это действие.';

  @override
  String nackValidation(int limit) {
    return 'Слишком длинный текст: максимум $limit символов.';
  }

  @override
  String nackVersionConflict(String name) {
    return 'Карточку уже переместил $name.';
  }

  @override
  String get nackVersionConflictUnknown =>
      'Карточку уже изменил другой участник.';

  @override
  String get nackNotFound => 'Карточка уже в архиве.';

  @override
  String get nackInternal => 'Не удалось сохранить. Пробуем ещё раз…';

  @override
  String get nackInternalFinal => 'Не удалось сохранить изменение.';

  @override
  String get nackRateLimited =>
      'Слишком много изменений. Попробуйте через минуту.';

  @override
  String get snackbarDismiss => 'Понятно';
}
