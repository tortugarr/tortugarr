import 'server_discovery_types.dart';

class ServerDiscoveryService {
  Stream<DiscoveredServer> discoverLocalServers() {
    return const Stream<DiscoveredServer>.empty();
  }
}