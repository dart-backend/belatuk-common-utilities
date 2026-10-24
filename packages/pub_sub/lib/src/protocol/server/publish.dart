/// Represents a request to publish information to other clients.
abstract class PublishRequest {
  /// The ID of the client sending this request.
  String? get clientId;

  /// Identifies the connection this request arrived on, if the adapter tracks
  /// connections. Must be unique across all adapters of a `Server`.
  ///
  /// A trusted client that sends no client ID is assigned one ad-hoc ID per
  /// connection, and that connection's subscriptions are cancelled when the
  /// adapter reports it on `Adapter.onDisconnect`.
  String? get connectionId => null;

  /// The name of the event to be sent.
  String? get eventName;

  /// The value to be published as an event.
  Object? get value;

  /// Accept the request, with a response.
  void accept(PublishResponse response);

  /// Deny the request with an error message.
  void reject(String errorMessage);
}

/// A response to a publish request. Informs the caller of how much clients received the event.
class PublishResponse {
  /// The number of unique listeners to whom this event was propogated.
  final int listeners;

  /// The client ID returned the server. Significant in cases where an ad-hoc client was registered.
  final String? clientId;

  const PublishResponse(this.listeners, this.clientId);
}
