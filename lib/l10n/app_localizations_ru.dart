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
  String cardMeta(String name, String when) {
    return 'Создал $name · $when';
  }

  @override
  String get cardAgeJustNow => 'только что';

  @override
  String cardAgeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты назад',
      many: '$count минут назад',
      few: '$count минуты назад',
      one: '$count минуту назад',
    );
    return '$_temp0';
  }

  @override
  String get cardAgeToday => 'сегодня';

  @override
  String get cardAgeYesterday => 'вчера';

  @override
  String cardAgeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: '$count день назад',
    );
    return '$_temp0';
  }

  @override
  String cardAgeDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get cardTitleEditHint => 'Нажмите, чтобы изменить заголовок';

  @override
  String get cardTitleField => 'Заголовок карточки';

  @override
  String boardTitleCounter(int count, int limit) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$countString / $limitString';
  }

  @override
  String cardDescriptionCounter(int count, int limit) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$countString / $limitString';
  }

  @override
  String cardDescriptionTooLong(int limit) {
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Слишком длинное описание: максимум $limitString символов. Сохранение недоступно.';
  }

  @override
  String cardConflictTitle(String name) {
    return 'Описание изменил $name';
  }

  @override
  String get cardConflictTitleUnknown => 'Описание изменил другой участник';

  @override
  String get cardConflictBody =>
      'Ваш черновик сохранён. Перезаписать его версией или отменить свои правки?';

  @override
  String get cardConflictOverwrite => 'Перезаписать';

  @override
  String get cardConflictCancel => 'Отменить';

  @override
  String get cardConflictWaiting => 'Загружаем актуальную версию…';

  @override
  String get cardDraftLostArchived =>
      'Карточка в архиве. Ваш текст не сохранён.';

  @override
  String get cardDraftLostCreateRejected =>
      'Карточку не удалось создать. Ваш текст не сохранён.';

  @override
  String get cardDraftLostCopy => 'Скопировать';

  @override
  String get addCardTitle => 'Новая карточка';

  @override
  String get addCardHint => 'Заголовок карточки';

  @override
  String get addCardSubmit => 'Добавить';

  @override
  String get addCardCancel => 'Отмена';

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

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonLoading => 'Загрузка…';

  @override
  String get configTitle => 'Не задан адрес сервера';

  @override
  String get configHint =>
      'Запустите приложение с --dart-define-from-file=env/local.json';

  @override
  String get configCurrentValue => 'Текущее значение';

  @override
  String get configValueEmpty => 'не задано';

  @override
  String get configOpenDemo => 'Открыть демо-доску';

  @override
  String get splashRestoring => 'Восстанавливаем сессию…';

  @override
  String get splashUnavailableTitle => 'Не удалось подключиться';

  @override
  String get errorNetworkOffline =>
      'Нет соединения с сервером. Проверьте интернет и повторите.';

  @override
  String get errorNetworkTimeout =>
      'Сервер не отвечает. Повторите попытку позже.';

  @override
  String get errorBusy => 'Сервер занят. Повторите через несколько секунд.';

  @override
  String get errorRateLimited =>
      'Слишком много попыток. Попробуйте через минуту.';

  @override
  String errorRateLimitedSeconds(int seconds) {
    return 'Слишком много попыток. Попробуйте через $seconds с.';
  }

  @override
  String errorRateLimitedMinutes(int minutes) {
    return 'Слишком много попыток. Попробуйте через $minutes мин.';
  }

  @override
  String get errorForbidden => 'Нет прав на это действие.';

  @override
  String get errorNotFound =>
      'Не найдено. Возможно, доска удалена или у вас нет доступа.';

  @override
  String get errorValidation => 'Проверьте введённые данные.';

  @override
  String get errorUnknown => 'Что-то пошло не так. Повторите попытку.';

  @override
  String get errorSessionExpired => 'Сессия истекла, войдите снова.';

  @override
  String get errorSessionReused =>
      'Мы завершили все сессии из соображений безопасности. Войдите заново.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authName => 'Имя';

  @override
  String get authShowPassword => 'Показать пароль';

  @override
  String get authHidePassword => 'Скрыть пароль';

  @override
  String get loginTitle => 'С возвращением';

  @override
  String get loginSubtitle => 'Доски команды уже ждут.';

  @override
  String get loginSubtitleWide => 'Войдите, чтобы открыть свои доски.';

  @override
  String get loginSubmit => 'Войти';

  @override
  String get loginCreateAccount => 'Создать аккаунт';

  @override
  String get loginNoAccount => 'Нет аккаунта?';

  @override
  String get loginCreateLink => 'Создать';

  @override
  String get loginInvalidCredentials => 'Неверный email или пароль.';

  @override
  String get loginBrandHeadline => 'Доски, которые двигаются вместе с командой';

  @override
  String get loginBrandBody =>
      'Все видят изменения друг друга сразу. Работает и без сети — синхронизируем, как только связь вернётся.';

  @override
  String get registerTitle => 'Создать аккаунт';

  @override
  String get registerSubtitle => 'Так вас увидят коллеги на досках.';

  @override
  String get registerSubmit => 'Создать аккаунт';

  @override
  String get registerHaveAccount => 'Уже есть аккаунт?';

  @override
  String get registerSignIn => 'Войти';

  @override
  String get registerBack => 'Назад ко входу';

  @override
  String get registerEmailTaken =>
      'Этот email уже зарегистрирован. Войдите или используйте другой адрес.';

  @override
  String get avatarColorLabel => 'Цвет аватара';

  @override
  String get avatarColorOptional => 'Необязательно';

  @override
  String get avatarColorBlue => 'Синий';

  @override
  String get avatarColorGreen => 'Зелёный';

  @override
  String get avatarColorViolet => 'Фиолетовый';

  @override
  String get avatarColorPink => 'Малиновый';

  @override
  String get avatarColorAmber => 'Янтарный';

  @override
  String get fieldEmailRequired => 'Введите email';

  @override
  String get fieldEmailInvalid => 'Проверьте email';

  @override
  String get fieldNameRequired => 'Введите имя';

  @override
  String get fieldPasswordRequired => 'Введите пароль';

  @override
  String fieldPasswordTooShort(int min) {
    return 'Минимум $min символов';
  }

  @override
  String fieldTooLong(int max) {
    return 'Не больше $max символов';
  }

  @override
  String get boardsTitle => 'Мои доски';

  @override
  String get boardsSearchHint => 'Найти доску';

  @override
  String get boardsNew => 'Новая доска';

  @override
  String boardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count доски',
      many: '$count досок',
      few: '$count доски',
      one: '$count доска',
    );
    return '$_temp0';
  }

  @override
  String get boardsEmptyTitle => 'Здесь появятся ваши доски';

  @override
  String get boardsEmptyBody =>
      'Создайте первую доску — колонки и участников добавите уже на ней.';

  @override
  String get boardsEmptyAction => 'Создать доску';

  @override
  String get boardsLoadError => 'Не удалось загрузить доски';

  @override
  String get boardsNoResults => 'Ничего не найдено';

  @override
  String get boardsProfile => 'Профиль';

  @override
  String boardUpdatedAt(String when) {
    return 'изменено $when';
  }

  @override
  String boardSemantic(String title, String role) {
    return 'Доска «$title», $role';
  }

  @override
  String get newBoardTitle => 'Новая доска';

  @override
  String get newBoardName => 'Название';

  @override
  String get newBoardNote =>
      'Вы станете владельцем. Колонки и участников добавите уже на доске.';

  @override
  String get newBoardSubmit => 'Создать доску';

  @override
  String get newBoardRequired => 'Введите название';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileBack => 'Мои доски';

  @override
  String get profileSave => 'Сохранить';

  @override
  String get profileSaved => 'Профиль сохранён';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileSignOut => 'Выйти';

  @override
  String get profileSignOutNote =>
      'Выход завершает сессию только на этом устройстве';

  @override
  String get boardLoadingTitle => 'Загружаем доску…';

  @override
  String get boardLoadErrorTitle => 'Не удалось открыть доску';

  @override
  String get boardLoadErrorToList => 'К списку досок';

  @override
  String boardLoadErrorCode(String code) {
    return 'Код ошибки: $code';
  }

  @override
  String syncOfflineBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изменения ждут',
      many: '$count изменений ждут',
      few: '$count изменения ждут',
      one: '$count изменение ждёт',
    );
    return 'Нет сети · $_temp0';
  }

  @override
  String syncSummaryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изменения не удалось применить',
      many: '$count изменений не удалось применить',
      few: '$count изменения не удалось применить',
      one: '$count изменение не удалось применить',
    );
    return '$_temp0';
  }

  @override
  String get syncSummaryBody =>
      'Пока вас не было, доска изменилась. Остальное отправлено.';

  @override
  String get syncSummaryBodyAllFailed => 'Пока вас не было, доска изменилась.';

  @override
  String get syncSummaryHide => 'Скрыть';

  @override
  String get syncSummaryDetails => 'Подробнее';

  @override
  String rejectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изменения не применились',
      many: '$count изменений не применилось',
      few: '$count изменения не применились',
      one: '$count изменение не применилось',
    );
    return '$_temp0';
  }

  @override
  String get rejectedSubtitle => 'Пока вы были офлайн, доска поменялась.';

  @override
  String rejectedSubtitleSaved(int saved) {
    String _temp0 = intl.Intl.pluralLogic(
      saved,
      locale: localeName,
      other: 'Сохранено ещё $saved изменения.',
      many: 'Сохранено ещё $saved изменений.',
      few: 'Сохранено ещё $saved изменения.',
      one: 'Сохранено ещё $saved изменение.',
    );
    return 'Пока вы были офлайн, доска поменялась. $_temp0';
  }

  @override
  String get rejectedSemantic => 'Неприменённые изменения';

  @override
  String get rejectedClose => 'Понятно';

  @override
  String get rejectedShowOnBoard => 'Показать на доске';

  @override
  String get rejectedCopyText => 'Скопировать текст';

  @override
  String get rejectedCopied => 'Скопировано';

  @override
  String get rejectedKindMove => 'перемещение';

  @override
  String get rejectedKindCreate => 'создание';

  @override
  String get rejectedKindEditTitle => 'правка названия';

  @override
  String get rejectedKindEditDescription => 'правка описания';

  @override
  String get rejectedKindArchive => 'архивация';

  @override
  String get rejectedKindCreateColumn => 'новая колонка';

  @override
  String get rejectedKindRenameColumn => 'переименование колонки';

  @override
  String get rejectedKindMoveColumn => 'сдвиг колонки';

  @override
  String get rejectedKindArchiveColumn => 'архивация колонки';

  @override
  String get rejectedSubjectCard => 'Карточка';

  @override
  String get rejectedSubjectColumn => 'Колонка';

  @override
  String rejectedSubjectNewCard(String title) {
    return 'Новая карточка «$title»';
  }

  @override
  String rejectedSubjectNewColumn(String title) {
    return 'Новая колонка «$title»';
  }

  @override
  String rejectedSubjectMove(String title, String column) {
    return '$title → $column';
  }

  @override
  String get rejectedDropStale =>
      'Изменение слишком долго ждало отправки и было отменено.';

  @override
  String get rejectedDropGone =>
      'Карточки или колонки, к которым относилось изменение, больше нет на доске.';

  @override
  String get boardEndedRemovedTitle => 'Доступ к доске закрыт';

  @override
  String boardEndedRemovedBody(String title) {
    return 'Вас убрали из участников доски «$title». Ваши несохранённые изменения на ней отменены.';
  }

  @override
  String get boardEndedDeletedTitle => 'Доска удалена';

  @override
  String boardEndedDeletedBody(String title) {
    return 'Владелец удалил доску «$title».';
  }

  @override
  String get boardEndedAccessLostBody =>
      'Доступ к доске закрыт, или она удалена. Ваши несохранённые изменения на ней отменены.';

  @override
  String get boardEndedAction => 'К моим доскам';

  @override
  String get boardEndedUnsavedHeading => 'Несохранённый текст';

  @override
  String get protocolUpdateApp =>
      'Обновите приложение: сервер использует новые возможности.';

  @override
  String nackVersionConflictColumn(String name) {
    return 'Колонку уже переместил $name.';
  }

  @override
  String get nackVersionConflictColumnUnknown =>
      'Колонку уже переместил другой участник.';

  @override
  String get nackNotFoundColumn => 'Колонка уже в архиве.';

  @override
  String get columnNewHint => 'Название колонки';

  @override
  String get columnNewSemantic => 'Название новой колонки';

  @override
  String get columnNewCreate => 'Создать колонку';

  @override
  String get columnEmptyTitle => 'Колонка пуста';

  @override
  String get columnEmptyBody =>
      'Добавьте первую карточку или перетащите сюда из другой колонки.';

  @override
  String get columnEmptyBodyViewer => 'Карточек пока нет.';

  @override
  String get columnMenu => 'Меню колонки';

  @override
  String columnMenuSemantic(String title) {
    return 'Меню колонки «$title»';
  }

  @override
  String columnSheetSemantic(String title) {
    return 'Колонка «$title»';
  }

  @override
  String get columnNameLabel => 'Название колонки';

  @override
  String get columnMoveLeft => 'Сдвинуть левее';

  @override
  String get columnMoveRight => 'Сдвинуть правее';

  @override
  String columnArchiveTitle(String title) {
    return 'Архивировать «$title»?';
  }

  @override
  String columnArchiveCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '$count карточка',
    );
    return '$_temp0';
  }

  @override
  String columnArchiveBody(String cards) {
    return 'Вместе с колонкой в архив уйдут $cards. Участники доски сразу перестанут их видеть.';
  }

  @override
  String get columnArchiveBodyEmpty =>
      'В колонке нет карточек. Участники доски сразу перестанут видеть колонку.';

  @override
  String get columnArchiveCancel => 'Отмена';

  @override
  String get columnArchiveConfirm => 'В архив';

  @override
  String get cardComposerDescription => 'Описание';

  @override
  String get cardInlineEditCaption => 'Правка заголовка';

  @override
  String get cardInlineEditCancel => 'Отменить правку';

  @override
  String get cardInlineEditSave => 'Сохранить заголовок';

  @override
  String get cardInlineEditAction => 'Править заголовок на доске';

  @override
  String get inviteHeadline => 'Вас приглашают на доску';

  @override
  String get inviteNote =>
      'Роль и права назначил владелец доски. Вы увидите их сразу после присоединения.';

  @override
  String get inviteAccept => 'Присоединиться';

  @override
  String get inviteUnavailableTitle => 'Ссылка больше не работает';

  @override
  String get inviteUnavailableBody =>
      'Она отозвана, истекла или уже использована. Попросите пригласившего прислать новую.';

  @override
  String get inviteNotFoundTitle => 'Ссылка не найдена';

  @override
  String get inviteNotFoundBody =>
      'Проверьте, что ссылка скопирована целиком, или попросите прислать новую.';

  @override
  String get inviteToBoards => 'К моим доскам';

  @override
  String get inviteHaveLink => 'У меня есть ссылка';

  @override
  String get inviteLinkTitle => 'Открыть приглашение';

  @override
  String get inviteLinkField => 'Ссылка или код приглашения';

  @override
  String get inviteLinkRequired => 'Вставьте ссылку или код приглашения';

  @override
  String get inviteLinkInvalid =>
      'Это не похоже на ссылку-приглашение. Вставьте ссылку целиком.';

  @override
  String get inviteLinkSubmit => 'Открыть';

  @override
  String get boardSettingsTitle => 'Настройки доски';

  @override
  String get boardSettingsName => 'Название';

  @override
  String get boardSettingsSave => 'Сохранить';

  @override
  String get boardSettingsSaved => 'Название сохранено';

  @override
  String get boardSettingsRole => 'Ваша роль';

  @override
  String get boardSettingsDanger => 'Опасная зона';

  @override
  String get boardSettingsDeleteAction => 'Удалить доску';

  @override
  String get boardSettingsDeleteTitle => 'Удалить доску?';

  @override
  String boardSettingsDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count участника сразу потеряют доступ, а открытые у них экраны доски закроются.',
      many:
          '$count участников сразу потеряют доступ, а открытые у них экраны доски закроются.',
      few:
          '$count участника сразу потеряют доступ, а открытые у них экраны доски закроются.',
      one:
          '$count участник сразу потеряет доступ, а открытые у него экраны доски закроются.',
    );
    return '$_temp0';
  }

  @override
  String get boardSettingsDeleteAlone =>
      'Доска и все её карточки будут удалены без возможности восстановления.';

  @override
  String get boardSettingsDeleteConfirm => 'Удалить';

  @override
  String get boardSettingsLeaveAction => 'Покинуть доску';

  @override
  String get boardSettingsLeaveTitle => 'Покинуть доску?';

  @override
  String boardSettingsLeaveBody(String title) {
    return 'Вы потеряете доступ к «$title». Вернуться можно будет только по новой ссылке-приглашению.';
  }

  @override
  String get boardSettingsLeaveConfirm => 'Покинуть';

  @override
  String get boardSettingsBack => 'Назад к доске';
}
