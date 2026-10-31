import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef NowProvider = DateTime Function();

final nowProvider = Provider<NowProvider>((ref) => DateTime.now);
