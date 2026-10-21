import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:uuid/uuid.dart';

import '../../belatuk_pub_sub.dart';

/// Sends [params] as a [method] notification to [peer], unless the client
/// has already disconnected and there is nobody to send it to.
void _notify(json_rpc_2.Peer peer, String method, Object? params) {
  if (!peer.isClosed) peer.sendNotification(method, params);
}

/// Sends a failure response for the request [requestId] to [peer].
void _sendError(json_rpc_2.Peer peer, String requestId, String errorMessage) {
  _notify(peer, requestId, {
    'status': false,
    'request_id': requestId,
    'error_message': errorMessage,
  });
}

/// A [Adapter] implementation that communicates via JSON RPC 2.0.
class JsonRpc2Adapter extends Adapter {
  final StreamController<PublishRequest> _onPublish =
      StreamController<PublishRequest>();
  final StreamController<SubscriptionRequest> _onSubscribe =
      StreamController<SubscriptionRequest>();
  final StreamController<UnsubscriptionRequest> _onUnsubscribe =
      StreamController<UnsubscriptionRequest>();
  // Broadcast, so disconnects are not buffered when nothing listens.
  final StreamController<String> _onDisconnect =
      StreamController<String>.broadcast();

  final List<json_rpc_2.Peer> _peers = [];
  final Uuid _uuid = Uuid();

  StreamSubscription<StreamChannel<String>>? _clientSubscription;

  /// A [Stream] of incoming clients, who can both send and receive string data.
  final Stream<StreamChannel<String>> clientStream;

  /// If `true`, clients can connect through this endpoint, *without* providing a client ID.
  ///
  /// This can be a security vulnerability if you don't know what you're doing.
  /// If you *must* use this over the Internet, use an IP whitelist.
  final bool isTrusted;

  JsonRpc2Adapter(this.clientStream, {this.isTrusted = false});

  @override
  Stream<PublishRequest> get onPublish => _onPublish.stream;

  @override
  Stream<SubscriptionRequest> get onSubscribe => _onSubscribe.stream;

  @override
  Stream<UnsubscriptionRequest> get onUnsubscribe => _onUnsubscribe.stream;

  @override
  Stream<String> get onDisconnect => _onDisconnect.stream;

  /// Closes every client connection, and stops listening to [clientStream].
  ///
  /// Cancelling the subscription to [clientStream] may close its source; for
  /// example, a `ServerSocket`'s stream stops accepting connections.
  @override
  Future close() async {
    try {
      // Close the connections first, so no request arrives after the request
      // streams are closed. A connection that ended with an error is closed
      // all the same.
      await Future.wait([
        if (_clientSubscription != null) _clientSubscription!.cancel(),
        for (var peer in List.of(_peers))
          if (!peer.isClosed) peer.close().then((_) {}, onError: (_) {}),
      ]);
    } finally {
      _peers.clear();
      _onPublish.close();
      _onSubscribe.close();
      _onUnsubscribe.close();
      _onDisconnect.close();
    }
  }

  String? _getClientId(json_rpc_2.Parameters params) {
    try {
      return params['client_id'].asString;
    } catch (_) {
      return null;
    }
  }

  /// Registers a handler for a [method] that clients send as a notification.
  ///
  /// Notifications get no automatic error reply, so if the handler fails, the
  /// failure is sent back on the request's `request_id` instead.
  void _registerRequest(
    json_rpc_2.Peer peer,
    String method,
    void Function(json_rpc_2.Parameters params, String requestId) handler,
  ) {
    peer.registerMethod(method, (json_rpc_2.Parameters params) {
      // The disconnect may already have been reported, so this request must
      // not reach the server; there is nobody to respond to anyway.
      if (peer.isClosed) return;

      String requestId;
      try {
        requestId = params['request_id'].asString;
      } catch (_) {
        // There's no request to respond to.
        return;
      }

      try {
        handler(params, requestId);
      } catch (e) {
        var message = e is json_rpc_2.RpcException
            ? e.message
            : 'The server could not handle this request.';
        _sendError(peer, requestId, message);
      }
    });
  }

  @override
  void start() {
    _clientSubscription = clientStream.listen((client) {
      var peer = json_rpc_2.Peer(client);
      var connectionId = _uuid.v4();
      _peers.add(peer);

      _registerRequest(peer, 'publish', (params, requestId) {
        var rq = _JsonRpc2PublishRequestImpl(
          requestId,
          _getClientId(params),
          params['event_name'].asString,
          params['value'].valueOr(null),
          peer,
          connectionId,
        );
        _onPublish.add(rq);
      });

      _registerRequest(peer, 'subscribe', (params, requestId) {
        var rq = _JsonRpc2SubscriptionRequestImpl(
          _getClientId(params),
          params['event_name'].asString,
          requestId,
          peer,
          _uuid,
          connectionId,
        );
        _onSubscribe.add(rq);
      });

      _registerRequest(peer, 'unsubscribe', (params, requestId) {
        var rq = _JsonRpc2UnsubscriptionRequestImpl(
          _getClientId(params),
          params['subscription_id'].asString,
          peer,
          requestId,
          connectionId,
        );
        _onUnsubscribe.add(rq);
      });

      peer.listen();
      peer.done.whenComplete(() {
        _peers.remove(peer);
        if (!_onDisconnect.isClosed) _onDisconnect.add(connectionId);
      }).ignore();
    });
  }

  @override
  bool isTrustedPublishRequest(PublishRequest request) {
    return isTrusted;
  }

  @override
  bool isTrustedSubscriptionRequest(SubscriptionRequest request) {
    return isTrusted;
  }
}

class _JsonRpc2PublishRequestImpl extends PublishRequest {
  final String requestId;

  @override
  final String? clientId, eventName;

  @override
  final dynamic value;

  final json_rpc_2.Peer peer;

  @override
  final String connectionId;

  _JsonRpc2PublishRequestImpl(
    this.requestId,
    this.clientId,
    this.eventName,
    this.value,
    this.peer,
    this.connectionId,
  );

  @override
  void accept(PublishResponse response) {
    _notify(peer, requestId, {
      'status': true,
      'request_id': requestId,
      'result': {
        'listeners': response.listeners,
        'client_id': response.clientId,
      },
    });
  }

  @override
  void reject(String errorMessage) => _sendError(peer, requestId, errorMessage);
}

class _JsonRpc2SubscriptionRequestImpl extends SubscriptionRequest {
  @override
  final String? clientId, eventName;

  final String requestId;

  final json_rpc_2.Peer peer;

  final Uuid _uuid;

  @override
  final String connectionId;

  _JsonRpc2SubscriptionRequestImpl(
    this.clientId,
    this.eventName,
    this.requestId,
    this.peer,
    this._uuid,
    this.connectionId,
  );

  @override
  FutureOr<Subscription> accept(String? clientId) {
    var id = _uuid.v4();
    _notify(peer, requestId, {
      'status': true,
      'request_id': requestId,
      'subscription_id': id,
      'client_id': clientId,
    });
    return _JsonRpc2SubscriptionImpl(clientId, id, eventName, peer);
  }

  @override
  void reject(String errorMessage) => _sendError(peer, requestId, errorMessage);
}

class _JsonRpc2SubscriptionImpl extends Subscription {
  @override
  final String? clientId, id;

  final String? eventName;

  final json_rpc_2.Peer peer;

  _JsonRpc2SubscriptionImpl(this.clientId, this.id, this.eventName, this.peer);

  @override
  void dispatch(event) {
    _notify(peer, 'event', {'event_name': eventName, 'value': event});
  }
}

class _JsonRpc2UnsubscriptionRequestImpl extends UnsubscriptionRequest {
  @override
  final String? clientId;

  @override
  final String subscriptionId;

  final json_rpc_2.Peer peer;

  final String requestId;

  @override
  final String connectionId;

  _JsonRpc2UnsubscriptionRequestImpl(
    this.clientId,
    this.subscriptionId,
    this.peer,
    this.requestId,
    this.connectionId,
  );

  @override
  void accept() {
    _notify(peer, requestId, {'status': true, 'result': {}});
  }

  @override
  void reject(String errorMessage) => _sendError(peer, requestId, errorMessage);
}
