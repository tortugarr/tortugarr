abstract class AdminLiveTvApi {
  Future<List<Map<String, dynamic>>> getTunerHosts();
  Future<List<Map<String, dynamic>>> getTunerHostTypes();
  Future<Map<String, dynamic>> addTunerHost(Map<String, dynamic> tunerInfo);
  Future<void> removeTunerHost(String id);
  Future<void> resetTuner(String tunerId);
  Future<List<Map<String, dynamic>>> discoverTuners();

  Future<List<Map<String, dynamic>>> getListingProviders();
  Future<Map<String, dynamic>> addListingProvider(
    Map<String, dynamic> providerInfo, {
    bool validateLogin,
    bool validateListings,
  });
  Future<void> removeListingProvider(String id);

  Future<List<Map<String, dynamic>>> getSchedulesDirectCountries();
  Future<List<Map<String, dynamic>>> getListingProviderLineups({
    String? providerId,
    required String location,
    required String country,
  });

  Future<void> setChannelMappings(Map<String, dynamic> mappings);

  Future<Map<String, dynamic>> getLiveTvConfiguration();
  Future<void> updateLiveTvConfiguration(Map<String, dynamic> config);
}
