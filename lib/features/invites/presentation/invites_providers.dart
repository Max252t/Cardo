import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/dio_invites_api.dart';
import '../data/invites_api.dart';

final invitesApiProvider = Provider<InvitesApi>(
  (ref) => DioInvitesApi(ref.watch(dioProvider)),
);
