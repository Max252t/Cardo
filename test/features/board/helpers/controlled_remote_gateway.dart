import 'dart:async';

import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_session.dart';

import 'board_fixtures.dart';

class ControlledRemoteGateway extends ControlledGateway
    implements BoardRemoteFeed {
  ControlledRemoteGateway({super.initial});

  final StreamController<RemoteCardUpdate> _updates =
      StreamController<RemoteCardUpdate>.broadcast(sync: true);

  @override
  Stream<RemoteCardUpdate> get remoteUpdates => _updates.stream;

  void pushDescription(
    String cardId,
    String text, {
    required int descriptionVersion,
    String actorId = DemoIds.maxim,
    int seq = 1285,
  }) {
    final card = snapshot().board.cardById(cardId)!;
    _updates.add(
      RemoteCardUpdate(
        card: card.copyWith(
          description: text,
          descriptionVersion: descriptionVersion,
          version: card.version + 1,
          updatedBy: actorId,
          updatedAt: demoReferenceTime,
        ),
        seq: seq,
        actorId: actorId,
      ),
    );
  }

  Future<void> dispose() => _updates.close();
}

CardModel demoCard(String cardId) => demoBoard().cardById(cardId)!;
