import 'package:dio/dio.dart';

import '../data/database.dart';

/// What the sync service needs from the server. Tests replace this with a fake.
abstract class ReadingsApi {
  /// Completes normally on success. Throws on any failure.
  Future<void> upload(Reading reading);
}

class DioReadingsApi implements ReadingsApi {
  DioReadingsApi(this._dio);

  final Dio _dio;

  @override
  Future<void> upload(Reading r) async {
    // Dio throws for non-2xx, so 200 (already stored) and 201 (new) both
    // count as success. That is what makes retries safe.
    await _dio.post(
      '/readings',
      data: {
        'id': r.id,
        'type': r.type,
        'values': r.type == 'bp'
            ? {
                'systolic': r.systolic,
                'diastolic': r.diastolic,
                'pulse': r.pulse,
              }
            : {'temperatureF': r.temperatureF},
        'measuredAt': r.measuredAt.toUtc().toIso8601String(),
      },
    );
  }
}

Dio createDio(String baseUrl) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
}
