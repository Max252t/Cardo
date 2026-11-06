import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/dio_members_api.dart';
import '../data/members_api.dart';

final membersApiProvider = Provider<MembersApi>(
  (ref) => DioMembersApi(ref.watch(dioProvider)),
);
