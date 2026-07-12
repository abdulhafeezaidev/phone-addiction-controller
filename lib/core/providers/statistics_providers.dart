import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/interfaces/statistics_service.dart';
import 'service_providers.dart';

final appStatisticsProvider = FutureProvider<AppStatistics>((ref) async {
  final statsService = ref.watch(statisticsServiceProvider);
  return await statsService.getStatistics();
});
