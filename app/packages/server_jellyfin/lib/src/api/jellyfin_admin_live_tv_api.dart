import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

class JellyfinAdminLiveTvApi implements AdminLiveTvApi {
  final Dio _dio;

  JellyfinAdminLiveTvApi(this._dio);

  @override
  Future<List<Map<String, dynamic>>> getTunerHosts() async {
    final config = await getLiveTvConfiguration();
    final hosts = config['TunerHosts'];
    if (hosts is List) {
      return hosts.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getTunerHostTypes() async {
    final response = await _getWithFallback([
      '/LiveTv/TunerHosts/Types',
    ]);
    return _asList(response.data);
  }

  @override
  Future<Map<String, dynamic>> addTunerHost(Map<String, dynamic> tunerInfo) async {
    final response = await _postWithFallback([
      '/LiveTv/TunerHosts',
      '/LiveTv/Tuners',
    ], data: tunerInfo);
    return _asMap(response.data);
  }

  @override
  Future<void> removeTunerHost(String id) async {
    await _deleteWithFallback(
      [
        '/LiveTv/TunerHosts',
      ],
      queryParameters: {'id': id},
    );
  }

  @override
  Future<void> resetTuner(String tunerId) async {
    await _postWithFallback([
      '/LiveTv/TunerHosts/$tunerId/Reset',
      '/LiveTv/Tuners/$tunerId/Reset',
      '/LiveTv/Tuners/$tunerId/ResetTuner',
    ]);
  }

  @override
  Future<List<Map<String, dynamic>>> discoverTuners() async {
    final response = await _getWithFallback([
      '/LiveTv/Tuners/Discover',
      '/LiveTv/TunerHosts/Discover',
    ]);
    return _asList(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getListingProviders() async {
    final config = await getLiveTvConfiguration();
    final providers = config['ListingProviders'];
    if (providers is List) {
      return providers.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>> addListingProvider(
    Map<String, dynamic> providerInfo, {
    bool validateLogin = false,
    bool validateListings = false,
  }) async {
    final query = <String, dynamic>{
      if (validateLogin) 'validateLogin': true,
      if (validateListings) 'validateListings': true,
    };
    final response = await _postWithFallback(
      [
        '/LiveTv/ListingProviders',
        '/LiveTv/Listings/Providers',
      ],
      data: providerInfo,
      queryParameters: query.isEmpty ? null : query,
    );
    return _asMap(response.data);
  }

  @override
  Future<void> removeListingProvider(String id) async {
    await _deleteWithFallback(
      [
        '/LiveTv/ListingProviders',
      ],
      queryParameters: {'id': id},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getSchedulesDirectCountries() async {
    final response = await _getWithFallback([
      '/LiveTv/ListingProviders/SchedulesDirect/Countries',
    ]);
    final data = response.data;
    final countries = <Map<String, dynamic>>[];
    // The server groups countries by region, so flatten every region's list
    // into a single ordered set of {ShortName, FullName} entries.
    if (data is Map) {
      for (final region in data.values) {
        if (region is List) {
          countries.addAll(
            region.whereType<Map>().map((e) => e.cast<String, dynamic>()),
          );
        }
      }
    } else if (data is List) {
      countries.addAll(
        data.whereType<Map>().map((e) => e.cast<String, dynamic>()),
      );
    }
    return countries;
  }

  @override
  Future<List<Map<String, dynamic>>> getListingProviderLineups({
    String? providerId,
    required String location,
    required String country,
  }) async {
    final response = await _getWithFallback(
      ['/LiveTv/ListingProviders/Lineups'],
      queryParameters: {
        if (providerId != null && providerId.isNotEmpty) 'id': providerId,
        'location': location,
        'country': country,
      },
    );
    return _asList(response.data);
  }

  @override
  Future<void> setChannelMappings(Map<String, dynamic> mappings) async {
    await _postWithFallback([
      '/LiveTv/ChannelMappings',
      '/LiveTv/Channels/Mappings',
    ], data: mappings);
  }

  @override
  Future<Map<String, dynamic>> getLiveTvConfiguration() async {
    final response = await _getWithFallback([
      '/System/Configuration/livetv',
      '/System/Configuration/LiveTv',
    ]);
    return _asMap(response.data);
  }

  @override
  Future<void> updateLiveTvConfiguration(Map<String, dynamic> config) async {
    await _postWithFallback([
      '/System/Configuration/livetv',
      '/System/Configuration/LiveTv',
    ], data: config);
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (data is Map<String, dynamic>) {
      final items = data['Items'] ?? data['items'] ?? data['TunerHosts'] ?? data['Providers'];
      if (items is List) {
        return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  Future<Response<dynamic>> _getWithFallback(
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastDioError;
    for (final path in paths) {
      try {
        return await _dio.get(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 405 || status == 501) {
          lastDioError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastDioError ?? StateError('No live TV endpoint responded');
  }

  Future<Response<dynamic>> _postWithFallback(
    List<String> paths, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastDioError;
    for (final path in paths) {
      try {
        return await _dio.post(path, data: data, queryParameters: queryParameters);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 405 || status == 501) {
          lastDioError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastDioError ?? StateError('No live TV endpoint responded');
  }

  Future<void> _deleteWithFallback(
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastDioError;
    for (final path in paths) {
      try {
        await _dio.delete(path, queryParameters: queryParameters);
        return;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 405 || status == 501) {
          lastDioError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastDioError ?? StateError('No live TV endpoint responded');
  }
}
