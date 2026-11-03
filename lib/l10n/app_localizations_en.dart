// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cardo';

  @override
  String get brandName => 'cardo';

  @override
  String get logoSemanticLabel => 'cardo logo';

  @override
  String get connectionConnected => 'Online';

  @override
  String get connectionSyncing => 'Syncing';

  @override
  String get connectionReconnecting => 'Reconnecting';

  @override
  String connectionReconnectingIn(int seconds) {
    return 'Reconnecting · $seconds s';
  }

  @override
  String get connectionOffline => 'Offline';

  @override
  String connectionSemanticLabel(String status) {
    return 'Connection: $status';
  }

  @override
  String avatarOverflow(int count) {
    return '+$count';
  }

  @override
  String get cardDropPlaceholder => 'Card drop spot';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleEditor => 'Editor';

  @override
  String get roleViewer => 'Viewer';

  @override
  String roleSemanticLabel(String role) {
    return 'Role: $role';
  }

  @override
  String get cardDescription => 'Description';

  @override
  String get cardPending => 'Queued';

  @override
  String get cardDragging => 'Moving';

  @override
  String get cardRejected => 'Not applied';

  @override
  String cardEditingBy(String name) {
    return '$name is editing';
  }

  @override
  String cardUpdatedBy(String name) {
    return 'Updated by $name';
  }

  @override
  String presenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members on the board',
      one: '$count member on the board',
    );
    return '$_temp0';
  }

  @override
  String pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes pending',
      one: '$count change pending',
    );
    return '$_temp0';
  }

  @override
  String get previewTitle => 'Design system';

  @override
  String get previewLightTheme => 'Light theme';

  @override
  String get previewDarkTheme => 'Dark theme';

  @override
  String get previewSectionLogo => 'Logo';

  @override
  String get previewSectionCards => 'Card: states';

  @override
  String get previewSectionCardsDense => 'Card: desktop';

  @override
  String get previewSectionConnection => 'Connection';

  @override
  String get previewSectionRoles => 'Roles and presence';

  @override
  String get previewSectionButtons => 'Buttons and notifications';

  @override
  String get previewCardConfirmed => 'Fractional indexing for rank';

  @override
  String get previewCardPending => 'Presence in Redis with TTL';

  @override
  String get previewCardDragging => 'Convergence test: 1000 operations';

  @override
  String get previewCardRejected => 'Close codes 4003/4004';

  @override
  String get previewCardEditing => 'Read-only board screen';

  @override
  String get previewNameAnya => 'Anya';

  @override
  String get previewNameMaxim => 'Maxim';

  @override
  String get previewNameElena => 'Elena';

  @override
  String get previewNameOlga => 'Olga';

  @override
  String get previewNameDmitry => 'Dmitry';

  @override
  String get previewRejectReason => 'Maxim already moved this card';

  @override
  String get previewNewBoard => 'New board';

  @override
  String get previewInvite => 'Invite';

  @override
  String get previewCancel => 'Cancel';

  @override
  String get previewOverwrite => 'Overwrite';

  @override
  String get previewEmailHint => 'Colleague\'s email';

  @override
  String get previewShowSnackbar => 'Show notification';

  @override
  String get previewSnackbarMessage =>
      'Maxim already moved this card — it stayed in “Review”';

  @override
  String get previewSnackbarAction => 'Got it';

  @override
  String get boardBack => 'Back to boards';

  @override
  String get boardMenu => 'Board menu';

  @override
  String get boardAddCard => 'Add card';

  @override
  String get boardAddColumn => 'Column';

  @override
  String get boardAddColumnSemantic => 'Add column';

  @override
  String boardColumnSemantic(String title) {
    return 'Column “$title”';
  }

  @override
  String boardTabSemantic(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '$count card',
    );
    return '$title, $_temp0';
  }

  @override
  String boardPageIndicator(int index, int total) {
    return 'Column $index of $total';
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
  String get boardSearch => 'Search';

  @override
  String get boardSidebarBoards => 'Boards';

  @override
  String get boardNewBoard => 'New board';

  @override
  String get boardMembers => 'Members';

  @override
  String get boardInvite => 'Invite';

  @override
  String get boardComingSoon => 'Coming in a future version';

  @override
  String boardViewerBanner(String owner) {
    return 'You are a viewer: you can look but not edit. Access is managed by the owner, $owner.';
  }

  @override
  String get boardViewerBannerNoOwner =>
      'You are a viewer: you can look but not edit.';

  @override
  String get cardDragHint => 'Press and hold to drag';

  @override
  String cardMoveTo(String column) {
    return 'Move to “$column”';
  }

  @override
  String get cardPanelArchive => 'Archive';

  @override
  String get cardPanelClose => 'Close';

  @override
  String cardPanelVersion(int version) {
    return 'v$version';
  }

  @override
  String get cardPanelDescriptionHint => 'Add a description';

  @override
  String get cardPanelSave => 'Save';

  @override
  String get cardPanelMove => 'Move';

  @override
  String cardPanelSemantic(String title) {
    return 'Card “$title”';
  }

  @override
  String cardMeta(String name, String when) {
    return 'Created by $name · $when';
  }

  @override
  String get cardAgeJustNow => 'just now';

  @override
  String cardAgeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String get cardAgeToday => 'today';

  @override
  String get cardAgeYesterday => 'yesterday';

  @override
  String cardAgeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
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
  String get cardTitleEditHint => 'Tap to edit the title';

  @override
  String get cardTitleField => 'Card title';

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

    return 'Description is too long: $limitString characters maximum. Saving is unavailable.';
  }

  @override
  String cardConflictTitle(String name) {
    return '$name changed the description';
  }

  @override
  String get cardConflictTitleUnknown =>
      'Another member changed the description';

  @override
  String get cardConflictBody =>
      'Your draft is saved. Overwrite their version or discard your changes?';

  @override
  String get cardConflictOverwrite => 'Overwrite';

  @override
  String get cardConflictCancel => 'Discard';

  @override
  String get cardConflictWaiting => 'Loading the latest version…';

  @override
  String get cardDraftLostArchived =>
      'The card is archived. Your text was not saved.';

  @override
  String get cardDraftLostCreateRejected =>
      'The card could not be created. Your text was not saved.';

  @override
  String get cardDraftLostCopy => 'Copy';

  @override
  String get addCardTitle => 'New card';

  @override
  String get addCardHint => 'Card title';

  @override
  String get addCardSubmit => 'Add';

  @override
  String get addCardCancel => 'Cancel';

  @override
  String get nackForbidden => 'You don\'t have permission to do that.';

  @override
  String nackValidation(int limit) {
    return 'Text is too long: $limit characters maximum.';
  }

  @override
  String nackVersionConflict(String name) {
    return '$name already moved this card.';
  }

  @override
  String get nackVersionConflictUnknown =>
      'Another member already changed this card.';

  @override
  String get nackNotFound => 'The card is already archived.';

  @override
  String get nackInternal => 'Couldn\'t save. Trying again…';

  @override
  String get nackInternalFinal => 'Couldn\'t save the change.';

  @override
  String get nackRateLimited => 'Too many changes. Try again in a minute.';

  @override
  String get snackbarDismiss => 'Got it';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get configTitle => 'Server address is not set';

  @override
  String get configHint =>
      'Run the app with --dart-define-from-file=env/local.json';

  @override
  String get configCurrentValue => 'Current value';

  @override
  String get configValueEmpty => 'not set';

  @override
  String get configOpenDemo => 'Open demo board';

  @override
  String get splashRestoring => 'Restoring your session…';

  @override
  String get splashUnavailableTitle => 'Couldn\'t connect';

  @override
  String get errorNetworkOffline =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get errorNetworkTimeout =>
      'The server isn\'t responding. Try again later.';

  @override
  String get errorBusy => 'The server is busy. Try again in a few seconds.';

  @override
  String get errorRateLimited => 'Too many attempts. Try again in a minute.';

  @override
  String errorRateLimitedSeconds(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String errorRateLimitedMinutes(int minutes) {
    return 'Too many attempts. Try again in $minutes min.';
  }

  @override
  String get errorForbidden => 'You don\'t have permission to do that.';

  @override
  String get errorNotFound =>
      'Not found. The board may have been deleted or you may not have access.';

  @override
  String get errorValidation => 'Check the data you entered.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get errorSessionExpired => 'Your session expired. Sign in again.';

  @override
  String get errorSessionReused =>
      'We ended all sessions for security reasons. Sign in again.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authName => 'Name';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Your team\'s boards are waiting.';

  @override
  String get loginSubtitleWide => 'Sign in to open your boards.';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get loginNoAccount => 'No account yet?';

  @override
  String get loginCreateLink => 'Create one';

  @override
  String get loginInvalidCredentials => 'Wrong email or password.';

  @override
  String get loginBrandHeadline => 'Boards that move with your team';

  @override
  String get loginBrandBody =>
      'Everyone sees each other\'s changes instantly. Works offline too — we sync as soon as you\'re back online.';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle =>
      'This is how teammates will see you on boards.';

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String get registerSignIn => 'Sign in';

  @override
  String get registerBack => 'Back to sign in';

  @override
  String get registerEmailTaken =>
      'This email is already registered. Sign in or use another address.';

  @override
  String get avatarColorLabel => 'Avatar color';

  @override
  String get avatarColorOptional => 'Optional';

  @override
  String get avatarColorBlue => 'Blue';

  @override
  String get avatarColorGreen => 'Green';

  @override
  String get avatarColorViolet => 'Violet';

  @override
  String get avatarColorPink => 'Pink';

  @override
  String get avatarColorAmber => 'Amber';

  @override
  String get fieldEmailRequired => 'Enter your email';

  @override
  String get fieldEmailInvalid => 'Check the email address';

  @override
  String get fieldNameRequired => 'Enter your name';

  @override
  String get fieldPasswordRequired => 'Enter your password';

  @override
  String fieldPasswordTooShort(int min) {
    return 'At least $min characters';
  }

  @override
  String fieldTooLong(int max) {
    return 'No more than $max characters';
  }

  @override
  String get boardsTitle => 'My boards';

  @override
  String get boardsSearchHint => 'Find a board';

  @override
  String get boardsNew => 'New board';

  @override
  String boardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boards',
      one: '$count board',
    );
    return '$_temp0';
  }

  @override
  String get boardsEmptyTitle => 'Your boards will appear here';

  @override
  String get boardsEmptyBody =>
      'Create your first board — you can add columns and members there.';

  @override
  String get boardsEmptyAction => 'Create a board';

  @override
  String get boardsLoadError => 'Couldn\'t load your boards';

  @override
  String get boardsNoResults => 'Nothing found';

  @override
  String get boardsProfile => 'Profile';

  @override
  String boardUpdatedAt(String when) {
    return 'updated $when';
  }

  @override
  String boardSemantic(String title, String role) {
    return 'Board “$title”, $role';
  }

  @override
  String get newBoardTitle => 'New board';

  @override
  String get newBoardName => 'Title';

  @override
  String get newBoardNote =>
      'You\'ll be the owner. Add columns and members on the board itself.';

  @override
  String get newBoardSubmit => 'Create board';

  @override
  String get newBoardRequired => 'Enter a title';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileBack => 'My boards';

  @override
  String get profileSave => 'Save';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignOutNote =>
      'Signing out ends the session on this device only';

  @override
  String get boardLoadingTitle => 'Loading the board…';

  @override
  String get boardLoadErrorTitle => 'Couldn\'t open the board';

  @override
  String get boardLoadErrorToList => 'Back to boards';

  @override
  String boardLoadErrorCode(String code) {
    return 'Error code: $code';
  }

  @override
  String syncOfflineBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '$count change waiting',
    );
    return 'No connection · $_temp0';
  }

  @override
  String syncSummaryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes could not be applied',
      one: '$count change could not be applied',
    );
    return '$_temp0';
  }

  @override
  String get syncSummaryBody =>
      'The board changed while you were away. Everything else was sent.';

  @override
  String get syncSummaryBodyAllFailed =>
      'The board changed while you were away.';

  @override
  String get syncSummaryHide => 'Hide';

  @override
  String get syncSummaryDetails => 'Details';

  @override
  String rejectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes not applied',
      one: '$count change not applied',
    );
    return '$_temp0';
  }

  @override
  String get rejectedSubtitle => 'The board changed while you were offline.';

  @override
  String rejectedSubtitleSaved(int saved) {
    String _temp0 = intl.Intl.pluralLogic(
      saved,
      locale: localeName,
      other: '$saved other changes were saved.',
      one: '$saved other change was saved.',
    );
    return 'The board changed while you were offline. $_temp0';
  }

  @override
  String get rejectedSemantic => 'Changes that weren\'t applied';

  @override
  String get rejectedClose => 'Got it';

  @override
  String get rejectedShowOnBoard => 'Show on board';

  @override
  String get rejectedCopyText => 'Copy text';

  @override
  String get rejectedCopied => 'Copied';

  @override
  String get rejectedKindMove => 'move';

  @override
  String get rejectedKindCreate => 'create';

  @override
  String get rejectedKindEditTitle => 'rename';

  @override
  String get rejectedKindEditDescription => 'description edit';

  @override
  String get rejectedKindArchive => 'archive';

  @override
  String get rejectedKindCreateColumn => 'new column';

  @override
  String get rejectedKindRenameColumn => 'column rename';

  @override
  String get rejectedKindMoveColumn => 'column move';

  @override
  String get rejectedKindArchiveColumn => 'column archive';

  @override
  String get rejectedSubjectCard => 'Card';

  @override
  String get rejectedSubjectColumn => 'Column';

  @override
  String rejectedSubjectNewCard(String title) {
    return 'New card “$title”';
  }

  @override
  String rejectedSubjectNewColumn(String title) {
    return 'New column “$title”';
  }

  @override
  String rejectedSubjectMove(String title, String column) {
    return '$title → $column';
  }

  @override
  String get rejectedDropStale =>
      'The change waited too long to be sent and was discarded.';

  @override
  String get rejectedDropGone =>
      'The card or column this change belonged to is no longer on the board.';

  @override
  String get boardEndedRemovedTitle => 'Access to the board is closed';

  @override
  String boardEndedRemovedBody(String title) {
    return 'You were removed from the members of “$title”. Your unsaved changes there were discarded.';
  }

  @override
  String get boardEndedDeletedTitle => 'Board deleted';

  @override
  String boardEndedDeletedBody(String title) {
    return 'The owner deleted “$title”.';
  }

  @override
  String get boardEndedAccessLostBody =>
      'Access to the board was revoked or it was deleted. Your unsaved changes there were discarded.';

  @override
  String get boardEndedAction => 'To my boards';

  @override
  String get boardEndedUnsavedHeading => 'Unsaved text';

  @override
  String get protocolUpdateApp =>
      'Update the app: the server uses newer features.';

  @override
  String get cardComposerDescription => 'Description';

  @override
  String get cardInlineEditCaption => 'Editing title';

  @override
  String get cardInlineEditCancel => 'Cancel editing';

  @override
  String get cardInlineEditSave => 'Save title';

  @override
  String get cardInlineEditAction => 'Edit title on the board';
}
