import 'package:server_core/server_core.dart';

class DiscoveredServer {
  final String id;
  final String name;
  final String address;
  final ServerType serverType;

  const DiscoveredServer({
    required this.id,
    required this.name,
    required this.address,
    required this.serverType,
  });
}