import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/board_settings_api.dart';
import '../data/dio_board_settings_api.dart';

final boardSettingsApiProvider = Provider<BoardSettingsApi>(
  (ref) => DioBoardSettingsApi(ref.watch(dioProvider)),
);
