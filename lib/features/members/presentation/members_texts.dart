import '../../../core/network/api_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/api_failure_text.dart';
import '../../../shared/widgets/role_badge.dart';
import '../domain/board_invite.dart';

const String alreadyMemberCode = 'already_member';

String addMemberFailureText(AppLocalizations l10n, ApiFailure failure) {
  return switch (failure) {
    NotFoundFailure() => l10n.membersErrorNotFound,
    ValidationFailure() => l10n.membersErrorValidation,
    ForbiddenFailure() => l10n.membersErrorForbidden,
    UnknownFailure(:final code) when code == alreadyMemberCode =>
      l10n.membersErrorAlreadyMember,
    _ => describeApiFailure(l10n, failure),
  };
}

String actionFailureText(AppLocalizations l10n, ApiFailure failure) {
  return switch (failure) {
    ForbiddenFailure() => l10n.membersErrorForbidden,
    _ => describeApiFailure(l10n, failure),
  };
}

String inviteExpiryText(
  AppLocalizations l10n,
  BoardInvite invite,
  DateTime now,
) {
  if (invite.isExpiredAt(now)) {
    return l10n.invitesExpired;
  }
  final left = invite.expiresAt.difference(now);
  if (left.inDays >= 1) {
    return l10n.invitesLeftDays(left.inDays);
  }
  if (left.inHours >= 1) {
    return l10n.invitesLeftHours(left.inHours);
  }
  final minutes = left.inMinutes < 1 ? 1 : left.inMinutes;
  return l10n.invitesLeftMinutes(minutes);
}

String inviteMetaText(AppLocalizations l10n, BoardInvite invite, DateTime now) {
  return l10n.invitesMeta(
    RoleBadge.labelFor(l10n, invite.role),
    inviteExpiryText(l10n, invite, now),
    l10n.invitesUses(invite.uses, invite.maxUses),
  );
}
