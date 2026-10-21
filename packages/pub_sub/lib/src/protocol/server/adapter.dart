import 'dart:async';

import 'publish.dart';
import 'subscription.dart';

/// Adapts an abstract medium to serve the `pub_sub` RPC protocol.
abstract class Adapter {
  /// Determines if a given [request] comes from a trusted source.
  ///
  /// If so, the request does not have to provide a pre-established ID,
  /// and instead will be assigned one.
  bool isTrustedPublishRequest(PublishRequest request);

  bool isTrustedSubscriptionRequest(SubscriptionRequest request);

  /// Fires an event whenever a client tries to publish data.
  Stream<PublishRequest> get onPublish;

  /// Fires whenever a client tries to subscribe to an event.
  Stream<SubscriptionRequest> get onSubscribe;

  /// Fires whenever a client cancels a subscription.
  Stream<UnsubscriptionRequest> get onUnsubscribe;

  /// Fires with a request's `connectionId` when that connection closes.
  ///
  /// Once a connection is reported here, the adapter must not deliver any more
  /// requests for it. Adapters that do not track connections never fire this.
  Stream<String> get onDisconnect => const Stream.empty();

  /// Disposes of this adapter.
  Future close();

  /// Start listening for incoming clients.
  void start();
}
