import 'dart:async';

/// Represents a request to subscribe to an event.
abstract class SubscriptionRequest {
  /// The ID of the client requesting to subscribe.
  String? get clientId;

  /// Identifies the connection this request arrived on, if the adapter tracks
  /// connections. Must be unique across all adapters of a `Server`.
  ///
  /// A trusted client that sends no client ID is assigned one ad-hoc ID per
  /// connection, and that connection's subscriptions are cancelled when the
  /// adapter reports it on `Adapter.onDisconnect`.
  String? get connectionId => null;

  /// The name of the event the client wants to subscribe to.
  String? get eventName;

  /// Accept the request, and grant the client access to subscribe to the event.
  ///
  /// Includes the client's ID, which is necessary for ad-hoc clients.
  FutureOr<Subscription> accept(String? clientId);

  /// Deny the request with an error message.
  void reject(String errorMessage);
}

/// Represents a request to unsubscribe to an event.
abstract class UnsubscriptionRequest {
  /// The ID of the client requesting to unsubscribe.
  String? get clientId;

  /// Identifies the connection this request arrived on, if the adapter tracks
  /// connections. A request without a client ID is checked against the
  /// connection's ad-hoc ID.
  String? get connectionId => null;

  /// The name of the event the client wants to unsubscribe from.
  String? get subscriptionId;

  /// Accept the request.
  FutureOr<void> accept();

  /// Deny the request with an error message.
  void reject(String errorMessage);
}

/// Represents a client's subscription to an event.
///
/// Also provides a means to fire an event.
abstract class Subscription {
  /// A unique identifier for this subscription.
  String? get id;

  /// The ID of the client who requested this subscription.
  String? get clientId;

  /// Alerts a client of an event.
  void dispatch(dynamic event);
}
