import 'dart:async';
import 'dart:isolate';

import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';
import 'shared.dart';

/// A [Adapter] implementation that communicates via [SendPort]s and [ReceivePort]s.
class IsolateAdapter extends Adapter {
  final Map<String, SendPort> _clients = {};
  final StreamController<PublishRequest> _onPublish =
      StreamController<PublishRequest>();
  final StreamController<SubscriptionRequest> _onSubscribe =
      StreamController<SubscriptionRequest>();
  final StreamController<UnsubscriptionRequest> _onUnsubscribe =
      StreamController<UnsubscriptionRequest>();
  // Broadcast, so disconnects are not buffered when nothing listens.
  final StreamController<String> _onDisconnect =
      StreamController<String>.broadcast();
  final Uuid _uuid = Uuid();

  /// A [ReceivePort] on which to listen for incoming data.
  final ReceivePort receivePort = ReceivePort();

  @override
  Stream<PublishRequest> get onPublish => _onPublish.stream;

  @override
  Stream<SubscriptionRequest> get onSubscribe => _onSubscribe.stream;

  @override
  Stream<UnsubscriptionRequest> get onUnsubscribe => _onUnsubscribe.stream;

  @override
  Stream<String> get onDisconnect => _onDisconnect.stream;

  @override
  Future close() {
    receivePort.close();
    _clients.keys.forEach(_onDisconnect.add);
    _clients.clear();
    _onPublish.close();
    _onSubscribe.close();
    _onUnsubscribe.close();
    _onDisconnect.close();
    return Future.value();
  }

  @override
  void start() {
    receivePort.listen((data) {
      if (data is SendPort) {
        var id = _uuid.v4();
        _clients[id] = data;
        data.send(messageHandler.encodeSendPortResponseMessage(id));
      } else if (data is Map<String, Object?>) {
        var (id, method, requestId, params) = messageHandler
            .decodeRequestMessage(data);
        var (clientId, eventName, subscriptionId, value) = messageHandler
            .decodeRequestParams(params);

        var sp = _clients[id];
        if (sp == null) {
          // There's nobody to respond to, so don't send anything to anyone
          return;
        }

        if (method == 'disconnect') {
          _clients.remove(id);
          _onDisconnect.add(id);
        } else if (method == 'publish') {
          if (eventName == null) {
            sp.send(messageHandler.encodePublishResponseError(requestId));
            return;
          }
          var rq = _IsolatePublishRequestImpl(
            requestId,
            clientId,
            eventName,
            value,
            sp,
            id,
          );
          _onPublish.add(rq);
        } else if (method == 'subscribe') {
          if (eventName == null) {
            sp.send(messageHandler.encodeSubscriptionResponseError(requestId));
            return;
          }
          var rq = _IsolateSubscriptionRequestImpl(
            clientId,
            eventName,
            sp,
            requestId,
            _uuid,
            id,
          );
          _onSubscribe.add(rq);
        } else if (method == 'unsubscribe') {
          if (subscriptionId == null) {
            sp.send(
              messageHandler.encodeUnsubscriptionResponseError(requestId),
            );
            return;
          }
          var rq = _IsolateUnsubscriptionRequestImpl(
            clientId,
            subscriptionId,
            sp,
            requestId,
            id,
          );
          _onUnsubscribe.add(rq);
        } else {
          sp.send(
            messageHandler.encodeUnknownMethodResponseError(requestId, method),
          );
        }
      }
    });
  }

  @override
  bool isTrustedPublishRequest(PublishRequest request) {
    // Isolate clients are considered trusted, because they are
    // running in the same process as the central server.
    return true;
  }

  @override
  bool isTrustedSubscriptionRequest(SubscriptionRequest request) {
    return true;
  }
}

class _IsolatePublishRequestImpl extends PublishRequest {
  @override
  final String? clientId;

  @override
  final String? eventName;

  @override
  final Object? value;

  final SendPort sendPort;

  final String? requestId;

  @override
  final String connectionId;

  _IsolatePublishRequestImpl(
    this.requestId,
    this.clientId,
    this.eventName,
    this.value,
    this.sendPort,
    this.connectionId,
  );

  @override
  void reject(String errorMessage) {
    sendPort.send(
      messageHandler.encodePublishResponseError(
        requestId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  void accept(PublishResponse response) {
    sendPort.send(
      messageHandler.encodePublishResponseMessage(
        requestId,
        response.listeners,
        response.clientId,
      ),
    );
  }
}

class _IsolateSubscriptionRequestImpl extends SubscriptionRequest {
  @override
  final String? clientId;

  @override
  final String? eventName;

  final SendPort sendPort;

  final String? requestId;

  final Uuid _uuid;

  @override
  final String connectionId;

  _IsolateSubscriptionRequestImpl(
    this.clientId,
    this.eventName,
    this.sendPort,
    this.requestId,
    this._uuid,
    this.connectionId,
  );

  @override
  void reject(String errorMessage) {
    sendPort.send(
      messageHandler.encodeSubscriptionResponseError(
        requestId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  FutureOr<Subscription> accept(String? clientId) {
    var id = _uuid.v4();
    sendPort.send(
      messageHandler.encodeSubscriptionResponseMessage(requestId, id, clientId),
    );
    return _IsolateSubscriptionImpl(clientId, id, eventName, sendPort);
  }
}

class _IsolateSubscriptionImpl extends Subscription {
  @override
  final String? clientId, id;

  final String? eventName;

  final SendPort sendPort;

  _IsolateSubscriptionImpl(
    this.clientId,
    this.id,
    this.eventName,
    this.sendPort,
  );

  @override
  void dispatch(event) {
    sendPort.send([eventName, event]);
  }
}

class _IsolateUnsubscriptionRequestImpl extends UnsubscriptionRequest {
  @override
  final String? clientId;

  @override
  final String? subscriptionId;

  final SendPort sendPort;

  final String? requestId;

  @override
  final String connectionId;

  _IsolateUnsubscriptionRequestImpl(
    this.clientId,
    this.subscriptionId,
    this.sendPort,
    this.requestId,
    this.connectionId,
  );

  @override
  void reject(String errorMessage) {
    sendPort.send(
      messageHandler.encodeUnsubscriptionResponseError(
        requestId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  void accept() {
    sendPort.send(
      messageHandler.encodeUnsubscriptionResponseMessage(requestId),
    );
  }
}
