import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// Название приложения в заголовке окна и переключателе задач
  ///
  /// In ru, this message translates to:
  /// **'Cardo'**
  String get appTitle;

  /// Словесный знак рядом с логотипом
  ///
  /// In ru, this message translates to:
  /// **'cardo'**
  String get brandName;

  /// Метка логотипа для экранного диктора
  ///
  /// In ru, this message translates to:
  /// **'Логотип cardo'**
  String get logoSemanticLabel;

  /// Статус соединения: подключено
  ///
  /// In ru, this message translates to:
  /// **'В сети'**
  String get connectionConnected;

  /// Статус соединения: идёт синхронизация
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get connectionSyncing;

  /// Статус соединения: переподключение без известного времени
  ///
  /// In ru, this message translates to:
  /// **'Переподключение'**
  String get connectionReconnecting;

  /// Статус соединения: переподключение через N секунд
  ///
  /// In ru, this message translates to:
  /// **'Переподключение · {seconds} с'**
  String connectionReconnectingIn(int seconds);

  /// Статус соединения: нет сети
  ///
  /// In ru, this message translates to:
  /// **'Офлайн'**
  String get connectionOffline;

  /// Метка индикатора соединения для экранного диктора
  ///
  /// In ru, this message translates to:
  /// **'Соединение: {status}'**
  String connectionSemanticLabel(String status);

  /// Счётчик участников, не поместившихся в стек аватаров
  ///
  /// In ru, this message translates to:
  /// **'+{count}'**
  String avatarOverflow(int count);

  /// Метка плейсхолдера вставки при перетаскивании
  ///
  /// In ru, this message translates to:
  /// **'Место для карточки'**
  String get cardDropPlaceholder;

  /// Роль участника доски: владелец
  ///
  /// In ru, this message translates to:
  /// **'Владелец'**
  String get roleOwner;

  /// Роль участника доски: редактор
  ///
  /// In ru, this message translates to:
  /// **'Редактор'**
  String get roleEditor;

  /// Роль участника доски: только просмотр
  ///
  /// In ru, this message translates to:
  /// **'Наблюдатель'**
  String get roleViewer;

  /// Метка бейджа роли для экранного диктора
  ///
  /// In ru, this message translates to:
  /// **'Роль: {role}'**
  String roleSemanticLabel(String role);

  /// Признак наличия описания в футере карточки
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get cardDescription;

  /// Карточка ждёт подтверждения сервером
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get cardPending;

  /// Карточка перетаскивается
  ///
  /// In ru, this message translates to:
  /// **'Перемещение'**
  String get cardDragging;

  /// Операция над карточкой отклонена сервером
  ///
  /// In ru, this message translates to:
  /// **'Не применено'**
  String get cardRejected;

  /// Ярлык на карточке, которую сейчас редактирует другой участник
  ///
  /// In ru, this message translates to:
  /// **'{name} редактирует'**
  String cardEditingBy(String name);

  /// Метка аватара последнего изменившего карточку
  ///
  /// In ru, this message translates to:
  /// **'Изменил {name}'**
  String cardUpdatedBy(String name);

  /// Метка стека аватаров присутствующих
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} участник на доске} few{{count} участника на доске} many{{count} участников на доске} other{{count} участника на доске}}'**
  String presenceCount(int count);

  /// Количество неотправленных изменений
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} изменение ждёт} few{{count} изменения ждут} many{{count} изменений ждут} other{{count} изменения ждут}}'**
  String pendingChanges(int count);

  /// Заголовок экрана предпросмотра компонентов
  ///
  /// In ru, this message translates to:
  /// **'Дизайн-система'**
  String get previewTitle;

  /// Раздел предпросмотра в светлой теме
  ///
  /// In ru, this message translates to:
  /// **'Светлая тема'**
  String get previewLightTheme;

  /// Раздел предпросмотра в тёмной теме
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get previewDarkTheme;

  /// Раздел предпросмотра
  ///
  /// In ru, this message translates to:
  /// **'Логотип'**
  String get previewSectionLogo;

  /// Раздел предпросмотра
  ///
  /// In ru, this message translates to:
  /// **'Карточка: состояния'**
  String get previewSectionCards;

  /// Раздел предпросмотра
  ///
  /// In ru, this message translates to:
  /// **'Карточка: desktop'**
  String get previewSectionCardsDense;

  /// Раздел предпросмотра
  ///
  /// In ru, this message translates to:
  /// **'Соединение'**
  String get previewSectionConnection;

  /// Раздел предпросмотра
  ///
  /// In ru, this message translates to:
  /// **'Роли и присутствие'**
  String get previewSectionRoles;

  /// Раздел предпросмотра
  ///
  /// In ru, this message translates to:
  /// **'Кнопки и уведомления'**
  String get previewSectionButtons;

  /// Пример заголовка карточки
  ///
  /// In ru, this message translates to:
  /// **'Fractional indexing для rank'**
  String get previewCardConfirmed;

  /// Пример заголовка карточки
  ///
  /// In ru, this message translates to:
  /// **'Presence в Redis с TTL'**
  String get previewCardPending;

  /// Пример заголовка карточки
  ///
  /// In ru, this message translates to:
  /// **'Тест сходимости: 1000 операций'**
  String get previewCardDragging;

  /// Пример заголовка карточки
  ///
  /// In ru, this message translates to:
  /// **'Коды закрытия 4003/4004'**
  String get previewCardRejected;

  /// Пример заголовка карточки
  ///
  /// In ru, this message translates to:
  /// **'Экран доски только на чтение'**
  String get previewCardEditing;

  /// Пример имени участника
  ///
  /// In ru, this message translates to:
  /// **'Аня'**
  String get previewNameAnya;

  /// Пример имени участника
  ///
  /// In ru, this message translates to:
  /// **'Максим'**
  String get previewNameMaxim;

  /// Пример имени участника
  ///
  /// In ru, this message translates to:
  /// **'Елена'**
  String get previewNameElena;

  /// Пример имени участника
  ///
  /// In ru, this message translates to:
  /// **'Ольга'**
  String get previewNameOlga;

  /// Пример имени участника
  ///
  /// In ru, this message translates to:
  /// **'Дмитрий'**
  String get previewNameDmitry;

  /// Пример причины отклонения
  ///
  /// In ru, this message translates to:
  /// **'Карточку уже переместил Максим'**
  String get previewRejectReason;

  /// Пример primary-кнопки
  ///
  /// In ru, this message translates to:
  /// **'Новая доска'**
  String get previewNewBoard;

  /// Пример акцентной кнопки
  ///
  /// In ru, this message translates to:
  /// **'Пригласить'**
  String get previewInvite;

  /// Пример вторичной кнопки
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get previewCancel;

  /// Пример текстовой кнопки
  ///
  /// In ru, this message translates to:
  /// **'Перезаписать'**
  String get previewOverwrite;

  /// Пример поля ввода
  ///
  /// In ru, this message translates to:
  /// **'Email коллеги'**
  String get previewEmailHint;

  /// Кнопка показа примера snackbar
  ///
  /// In ru, this message translates to:
  /// **'Показать уведомление'**
  String get previewShowSnackbar;

  /// Пример текста snackbar
  ///
  /// In ru, this message translates to:
  /// **'Карточку уже переместил Максим — она осталась в «Ревью»'**
  String get previewSnackbarMessage;

  /// Пример действия snackbar
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get previewSnackbarAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
