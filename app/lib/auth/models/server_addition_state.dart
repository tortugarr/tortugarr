sealed class ServerAdditionState {
  const ServerAdditionState();
}

class ServerConnecting extends ServerAdditionState {
  final String address;
  const ServerConnecting({required this.address});
}

class ServerUnableToConnect extends ServerAdditionState {
  final List<String> candidatesTried;
  final String? lastCandidate;
  final String? lastErrorType;
  final int? lastStatusCode;
  final String? lastErrorMessage;

  const ServerUnableToConnect({
    required this.candidatesTried,
    this.lastCandidate,
    this.lastErrorType,
    this.lastStatusCode,
    this.lastErrorMessage,
  });
}

class ServerConnected extends ServerAdditionState {
  final String id;
  final Map<String, dynamic> publicInfo;
  const ServerConnected({required this.id, required this.publicInfo});
}
