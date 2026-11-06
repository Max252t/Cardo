import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/invite/invite_link.dart';
import '../../../core/models/board_role.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../domain/board_invite.dart';
import '../domain/invite_policy.dart';
import '../domain/roster_member.dart';
import 'members_providers.dart';

const Object _keep = Object();

@immutable
class MembersState {
  const MembersState({
    this.busyMembers = const <String>{},
    this.adding = false,
    this.addFailure,
    this.invites,
    this.invitesLoading = false,
    this.invitesFailure,
    this.creating = false,
    this.revoking = const <String>{},
    this.links = const <String, String>{},
    this.actionFailure,
  });

  final Set<String> busyMembers;
  final bool adding;
  final ApiFailure? addFailure;
  final List<BoardInvite>? invites;
  final bool invitesLoading;
  final ApiFailure? invitesFailure;
  final bool creating;
  final Set<String> revoking;
  final Map<String, String> links;
  final ApiFailure? actionFailure;

  MembersState copyWith({
    Set<String>? busyMembers,
    bool? adding,
    Object? addFailure = _keep,
    Object? invites = _keep,
    bool? invitesLoading,
    Object? invitesFailure = _keep,
    bool? creating,
    Set<String>? revoking,
    Map<String, String>? links,
    Object? actionFailure = _keep,
  }) {
    return MembersState(
      busyMembers: busyMembers ?? this.busyMembers,
      adding: adding ?? this.adding,
      addFailure: identical(addFailure, _keep)
          ? this.addFailure
          : addFailure as ApiFailure?,
      invites: identical(invites, _keep)
          ? this.invites
          : invites as List<BoardInvite>?,
      invitesLoading: invitesLoading ?? this.invitesLoading,
      invitesFailure: identical(invitesFailure, _keep)
          ? this.invitesFailure
          : invitesFailure as ApiFailure?,
      creating: creating ?? this.creating,
      revoking: revoking ?? this.revoking,
      links: links ?? this.links,
      actionFailure: identical(actionFailure, _keep)
          ? this.actionFailure
          : actionFailure as ApiFailure?,
    );
  }
}

class MembersController extends Notifier<MembersState> {
  MembersController(this.boardId);

  final String boardId;

  @override
  MembersState build() => const MembersState();

  Future<RosterMember?> addMember({
    required String email,
    required BoardRole role,
  }) async {
    if (state.adding) {
      return null;
    }
    state = state.copyWith(adding: true, addFailure: null, actionFailure: null);
    final result = await ref
        .read(membersApiProvider)
        .addMember(boardId, email: email.trim(), role: role);
    if (!ref.mounted) {
      return result.valueOrNull;
    }
    state = state.copyWith(adding: false, addFailure: result.failureOrNull);
    return result.valueOrNull;
  }

  void clearAddFailure() {
    if (state.addFailure != null && !state.adding) {
      state = state.copyWith(addFailure: null);
    }
  }

  Future<void> changeRole(String userId, BoardRole role) async {
    if (state.busyMembers.contains(userId)) {
      return;
    }
    state = state.copyWith(
      busyMembers: {...state.busyMembers, userId},
      actionFailure: null,
    );
    final result = await ref
        .read(membersApiProvider)
        .changeRole(boardId, userId, role);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      busyMembers: {...state.busyMembers}..remove(userId),
      actionFailure: result.failureOrNull ?? state.actionFailure,
    );
  }

  Future<void> removeMember(String userId) async {
    if (state.busyMembers.contains(userId)) {
      return;
    }
    state = state.copyWith(
      busyMembers: {...state.busyMembers, userId},
      actionFailure: null,
    );
    final result = await ref
        .read(membersApiProvider)
        .removeMember(boardId, userId);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      busyMembers: {...state.busyMembers}..remove(userId),
      actionFailure: result.failureOrNull ?? state.actionFailure,
    );
  }

  Future<void> loadInvites() async {
    if (state.invitesLoading) {
      return;
    }
    state = state.copyWith(invitesLoading: true, invitesFailure: null);
    final result = await ref.read(membersApiProvider).listInvites(boardId);
    if (!ref.mounted) {
      return;
    }
    state = switch (result) {
      Success<List<BoardInvite>, ApiFailure>(:final value) => state.copyWith(
        invitesLoading: false,
        invites: value,
      ),
      Failure<List<BoardInvite>, ApiFailure>(:final failure) => state.copyWith(
        invitesLoading: false,
        invitesFailure: failure,
      ),
    };
  }

  Future<bool> createInvite(BoardRole role) async {
    if (state.creating) {
      return false;
    }
    state = state.copyWith(creating: true, actionFailure: null);
    final result = await ref
        .read(membersApiProvider)
        .createInvite(
          boardId,
          role: role,
          expiresIn: InvitePolicy.defaultLifetime,
          maxUses: InvitePolicy.defaultMaxUses,
        );
    if (!ref.mounted) {
      return result.isSuccess;
    }
    switch (result) {
      case Success<CreatedInvite, ApiFailure>(:final value):
        state = state.copyWith(
          creating: false,
          invites: <BoardInvite>[value.invite, ...?state.invites],
          links: {
            ...state.links,
            value.invite.id: InviteLink.build(value.token),
          },
        );
        return true;
      case Failure<CreatedInvite, ApiFailure>(:final failure):
        state = state.copyWith(creating: false, actionFailure: failure);
        return false;
    }
  }

  Future<void> revokeInvite(String inviteId) async {
    if (state.revoking.contains(inviteId)) {
      return;
    }
    state = state.copyWith(
      revoking: {...state.revoking, inviteId},
      actionFailure: null,
    );
    final result = await ref
        .read(membersApiProvider)
        .revokeInvite(boardId, inviteId);
    if (!ref.mounted) {
      return;
    }
    final revoked = result.isSuccess || result.failureOrNull is NotFoundFailure;
    state = state.copyWith(
      revoking: {...state.revoking}..remove(inviteId),
      invites: revoked
          ? <BoardInvite>[
              for (final invite in state.invites ?? const <BoardInvite>[])
                if (invite.id != inviteId) invite,
            ]
          : state.invites,
      links: revoked ? ({...state.links}..remove(inviteId)) : state.links,
      actionFailure: revoked ? null : result.failureOrNull,
    );
  }

  void clearActionFailure() {
    if (state.actionFailure != null) {
      state = state.copyWith(actionFailure: null);
    }
  }
}

final membersControllerProvider = NotifierProvider.autoDispose
    .family<MembersController, MembersState, String>(MembersController.new);
