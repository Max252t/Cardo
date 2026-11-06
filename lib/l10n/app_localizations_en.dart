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
    return 'Reconnecting in ${seconds}s';
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
  String get cardDropPlaceholder => 'Drop card here';

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
    return 'You\'re a viewer: you can view but not edit. Ask the owner, $owner, for access.';
  }

  @override
  String get boardViewerBannerNoOwner =>
      'You\'re a viewer: you can view but not edit. Ask the owner for access.';

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
  String get cardTitleEditHint => 'Edit the title';

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

    return 'Description is too long: $limitString characters maximum. Shorten it to save.';
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
      'The card is archived. Your text wasn\'t saved.';

  @override
  String get cardDraftLostCreateRejected =>
      'The card couldn\'t be created. Your text wasn\'t saved.';

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
  String get nackNotFound => 'This card is already archived.';

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
  String get configTitle => 'Server address isn\'t set';

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
  String get boardsRefresh => 'Refresh';

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
      other: '$count changes couldn\'t be applied',
      one: '$count change couldn\'t be applied',
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
  String nackVersionConflictColumn(String name) {
    return '$name already moved this column.';
  }

  @override
  String get nackVersionConflictColumnUnknown =>
      'Another member already moved this column.';

  @override
  String get nackNotFoundColumn => 'The column is already archived.';

  @override
  String get columnNewHint => 'Column name';

  @override
  String get columnNewSemantic => 'New column name';

  @override
  String get columnNewCreate => 'Create column';

  @override
  String get columnEmptyTitle => 'Column is empty';

  @override
  String get columnEmptyBody =>
      'Add the first card or drag one here from another column.';

  @override
  String get columnEmptyBodyViewer => 'No cards yet.';

  @override
  String get columnMenu => 'Column menu';

  @override
  String columnMenuSemantic(String title) {
    return 'Column menu: $title';
  }

  @override
  String columnSheetSemantic(String title) {
    return 'Column “$title”';
  }

  @override
  String get columnNameLabel => 'Column name';

  @override
  String get columnMoveLeft => 'Move left';

  @override
  String get columnMoveRight => 'Move right';

  @override
  String columnArchiveTitle(String title) {
    return 'Archive “$title”?';
  }

  @override
  String columnArchiveCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '$count card',
    );
    return '$_temp0';
  }

  @override
  String columnArchiveBody(String cards) {
    return '$cards will be archived with the column. Board members will stop seeing them right away.';
  }

  @override
  String get columnArchiveBodyEmpty =>
      'The column has no cards. Board members will stop seeing the column right away.';

  @override
  String get columnArchiveCancel => 'Cancel';

  @override
  String get columnArchiveConfirm => 'Archive';

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

  @override
  String get membersTitle => 'Members';

  @override
  String membersSheetSemantic(String title) {
    return 'Members of “$title”';
  }

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String membersOnlineCount(int count) {
    return '$count online';
  }

  @override
  String membersSummary(String members, String online) {
    return '$members · $online';
  }

  @override
  String get membersYou => 'You';

  @override
  String get membersOnBoard => 'on the board';

  @override
  String get membersAddLabel => 'Colleague\'s email';

  @override
  String get membersAddAction => 'Add';

  @override
  String membersAdded(String name) {
    return 'Member added: $name';
  }

  @override
  String get membersErrorNotFound => 'No user with this email';

  @override
  String get membersErrorAlreadyMember => 'This user is already on the board';

  @override
  String get membersErrorValidation => 'Check the email and role';

  @override
  String get membersErrorForbidden => 'Only the board owner can manage members';

  @override
  String membersRoleChange(String name, String role) {
    return 'Change role: $name, currently $role';
  }

  @override
  String membersRoleForNew(String role) {
    return 'Role of the new member: $role';
  }

  @override
  String membersRemoveTooltip(String name) {
    return 'Remove from the board: $name';
  }

  @override
  String membersRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String membersRemoveBody(String board) {
    return 'They will lose access to “$board” right away. Their unsaved changes won\'t be kept.';
  }

  @override
  String get membersRemoveConfirm => 'Remove';

  @override
  String get invitesTitle => 'Invite link';

  @override
  String get invitesCreate => 'Create link';

  @override
  String invitesRoleForNew(String role) {
    return 'Role for the link: $role';
  }

  @override
  String invitesLinkSemantic(String link) {
    return 'Invite link: $link';
  }

  @override
  String get invitesCopy => 'Copy';

  @override
  String get invitesCopied => 'Copied';

  @override
  String get invitesRevoke => 'Revoke';

  @override
  String invitesRevokeSemantic(String meta) {
    return 'Revoke invite: $meta';
  }

  @override
  String invitesMeta(String role, String expiry, String uses) {
    return '$role · $expiry · $uses';
  }

  @override
  String invitesLeftDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '$count day left',
    );
    return '$_temp0';
  }

  @override
  String invitesLeftHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours left',
      one: '$count hour left',
    );
    return '$_temp0';
  }

  @override
  String invitesLeftMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes left',
      one: '$count minute left',
    );
    return '$_temp0';
  }

  @override
  String get invitesExpired => 'expired';

  @override
  String invitesUses(int used, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max uses',
      one: '$max use',
    );
    return '$used of $_temp0';
  }

  @override
  String get invitesEmpty =>
      'No active links. Create a link and send it to a colleague.';

  @override
  String get invitesTokenHint =>
      'A link can be copied only right after it is created.';

  @override
  String get invitesLoadError => 'Couldn\'t load invites';

  @override
  String get inviteHeadline => 'You\'re invited to a board';

  @override
  String get inviteNote =>
      'The board owner chose your role and permissions. You\'ll see them right after you join.';

  @override
  String get inviteAccept => 'Join';

  @override
  String get inviteUnavailableTitle => 'This link no longer works';

  @override
  String get inviteUnavailableBody =>
      'It was revoked, has expired or was already used. Ask the person who invited you to send a new one.';

  @override
  String get inviteNotFoundTitle => 'Link not found';

  @override
  String get inviteNotFoundBody =>
      'Check that the whole link was copied, or ask for a new one.';

  @override
  String get inviteToBoards => 'To my boards';

  @override
  String get inviteHaveLink => 'I have a link';

  @override
  String get inviteLinkTitle => 'Open an invitation';

  @override
  String get inviteLinkField => 'Invitation link or code';

  @override
  String get inviteLinkRequired => 'Paste an invitation link or code';

  @override
  String get inviteLinkInvalid =>
      'That doesn\'t look like an invitation link. Paste the whole link.';

  @override
  String get inviteLinkSubmit => 'Open';

  @override
  String get boardSettingsTitle => 'Board settings';

  @override
  String get boardSettingsName => 'Name';

  @override
  String get boardSettingsSave => 'Save';

  @override
  String get boardSettingsSaved => 'Name saved';

  @override
  String get boardSettingsRole => 'Your role';

  @override
  String get boardSettingsDanger => 'Danger zone';

  @override
  String get boardSettingsDeleteAction => 'Delete board';

  @override
  String get boardSettingsDeleteTitle => 'Delete this board?';

  @override
  String boardSettingsDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count members will lose access right away and their open board screens will close.',
      one:
          '$count member will lose access right away and their open board screens will close.',
    );
    return '$_temp0';
  }

  @override
  String get boardSettingsDeleteAlone =>
      'The board and all its cards will be deleted permanently.';

  @override
  String get boardSettingsDeleteConfirm => 'Delete';

  @override
  String get boardSettingsLeaveAction => 'Leave board';

  @override
  String get boardSettingsLeaveTitle => 'Leave this board?';

  @override
  String boardSettingsLeaveBody(String title) {
    return 'You\'ll lose access to “$title”. You can only come back with a new invitation link.';
  }

  @override
  String get boardSettingsLeaveConfirm => 'Leave';

  @override
  String get boardSettingsBack => 'Back to the board';
}
