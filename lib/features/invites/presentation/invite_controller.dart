import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../boards/domain/board_info.dart';
import '../../boards/presentation/boards_providers.dart';
import 'invites_providers.dart';

enum InviteProblem { unavailable, notFound }

const int _goneStatus = 410;

InviteProblem? inviteProblemOf(ApiFailure failure) {
  return switch (failure) {
    GoneFailure() => InviteProblem.unavailable,
    NotFoundFailure() => InviteProblem.notFound,
    UnknownFailure(:final code, :final statusCode)
        when code == 'invite_unavailable' || statusCode == _goneStatus =>
      InviteProblem.unavailable,
    _ => null,
  };
}

@immutable
class InviteState {
  const InviteState({this.accepting = false, this.problem, this.failure});

  final bool accepting;
  final InviteProblem? problem;
  final ApiFailure? failure;

  @override
  bool operator ==(Object other) {
    return other is InviteState &&
        other.accepting == accepting &&
        other.problem == problem &&
        other.failure == failure;
  }

  @override
  int get hashCode => Object.hash(accepting, problem, failure);
}

class InviteController extends Notifier<InviteState> {
  @override
  InviteState build() => const InviteState();

  Future<BoardInfo?> accept(String token) async {
    if (state.accepting) {
      return null;
    }
    state = const InviteState(accepting: true);
    final result = await ref.read(invitesApiProvider).acceptInvite(token);
    if (!ref.mounted) {
      return result.valueOrNull;
    }
    switch (result) {
      case Success<BoardInfo, ApiFailure>(:final value):
        ref.invalidate(boardsListProvider);
        state = const InviteState();
        return value;
      case Failure<BoardInfo, ApiFailure>(:final failure):
        final problem = inviteProblemOf(failure);
        state = InviteState(
          problem: problem,
          failure: problem == null ? failure : null,
        );
        return null;
    }
  }
}

final inviteControllerProvider =
    NotifierProvider.autoDispose<InviteController, InviteState>(
      InviteController.new,
    );
