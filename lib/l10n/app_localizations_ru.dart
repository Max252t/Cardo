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
}
