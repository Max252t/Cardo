import '../../../l10n/app_localizations.dart';
import '../domain/auth_validation.dart';
import '../domain/session.dart';

enum AuthField { name, email, password, loginPassword }

String? fieldIssueText(
  AppLocalizations l10n,
  AuthField field,
  FieldIssue? issue,
) {
  if (issue == null) {
    return null;
  }
  return switch ((field, issue)) {
    (AuthField.name, FieldIssue.tooLong) => l10n.fieldTooLong(
      AuthLimits.nameMax,
    ),
    (AuthField.name, _) => l10n.fieldNameRequired,
    (AuthField.email, FieldIssue.tooLong) => l10n.fieldTooLong(
      AuthLimits.emailMax,
    ),
    (AuthField.email, FieldIssue.invalidFormat) => l10n.fieldEmailInvalid,
    (AuthField.email, _) => l10n.fieldEmailRequired,
    (AuthField.password, FieldIssue.tooShort) => l10n.fieldPasswordTooShort(
      AuthLimits.passwordMin,
    ),
    (AuthField.password, FieldIssue.tooLong) => l10n.fieldTooLong(
      AuthLimits.passwordMax,
    ),
    (AuthField.password, _) => l10n.fieldPasswordRequired,
    (AuthField.loginPassword, _) => l10n.fieldPasswordRequired,
  };
}

String signOutReasonText(AppLocalizations l10n, SignOutReason reason) {
  return switch (reason) {
    SignOutReason.expired => l10n.errorSessionExpired,
    SignOutReason.reused => l10n.errorSessionReused,
  };
}
