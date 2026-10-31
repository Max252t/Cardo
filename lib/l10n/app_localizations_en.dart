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
}
