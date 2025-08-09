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
  Future close() {
    receivePort.close();
    _clients.clear();
    _onPublish.close();
    _onSubscribe.close();
    _onUnsubscribe.close();
    return Future.value();
  }

  @override
  void start() {
    receivePort.listen((data) {
      if (data is SendPort) {
        var id = _uuid.v4();
        _clients[id] = data;
        data.send(MessageHandler().encodeSendPortResponseMessage(id));
      } else if (data is Map<String, Object?>) {
        var (id, method, requestId, params) = MessageHandler()
            .decodeRequestMessage(data);
        var (clientId, eventName, subscriptionId, value) = MessageHandler()
            .decodeRequestParams(params);

        var sp = _clients[id];
        if (sp == null) {
          // There's nobody to respond to, so don't send anything to anyone
          return;
        }

        if (method == 'publish') {
          if (eventName == null || value == null) {
            sp.send(MessageHandler().encodePublishResponseError(requestId));
          }
          var rq = _IsolatePublishRequestImpl(
            requestId,
            clientId,
            eventName,
            value,
            sp,
          );
          _onPublish.add(rq);
        } else if (method == 'subscribe') {
          if (eventName == null) {
            sp.send(
              MessageHandler().encodeSubscriptionResponseError(requestId),
            );
          }
          var rq = _IsolateSubscriptionRequestImpl(
            clientId,
            eventName,
            sp,
            requestId,
            _uuid,
          );
          _onSubscribe.add(rq);
        } else if (method == 'unsubscribe') {
          if (subscriptionId == null) {
            sp.send(
              MessageHandler().encodeUnsubscriptionResponseError(requestId),
            );
          }
          var rq = _IsolateUnsubscriptionRequestImpl(
            clientId,
            subscriptionId,
            sp,
            requestId,
          );
          _onUnsubscribe.add(rq);
        } else {
          sp.send(
            MessageHandler().encodeUnknownMethodResponseError(
              requestId,
              method,
            ),
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

  _IsolatePublishRequestImpl(
    this.requestId,
    this.clientId,
    this.eventName,
    this.value,
    this.sendPort,
  );

  @override
  void reject(String errorMessage) {
    sendPort.send(
      MessageHandler().encodePublishResponseError(
        requestId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  void accept(PublishResponse response) {
    sendPort.send(
      MessageHandler().encodePublishResponseMessage2(
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

  _IsolateSubscriptionRequestImpl(
    this.clientId,
    this.eventName,
    this.sendPort,
    this.requestId,
    this._uuid,
  );

  @override
  void reject(String errorMessage) {
    sendPort.send(
      MessageHandler().encodeSubscriptionResponseError(
        requestId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  FutureOr<Subscription> accept(String? clientId) {
    var id = _uuid.v4();
    sendPort.send(
      MessageHandler().encodeSubscriptionResponseMessage(
        requestId,
        id,
        clientId,
      ),
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

  _IsolateUnsubscriptionRequestImpl(
    this.clientId,
    this.subscriptionId,
    this.sendPort,
    this.requestId,
  );

  @override
  void reject(String errorMessage) {
    sendPort.send(
      MessageHandler().encodeUnsubscriptionResponseError(
        requestId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  void accept() {
    sendPort.send(
      MessageHandler().encodeUnsubscriptionResponseMessage(requestId),
    );
  }
}
