/// A message handler class that handles the encoding/decoding of messages send
/// between isolate [Client] and [Server].
class MessageHandler {
  static const _requestId = 'request_id';
  static const _method = 'method';
  static const _clientId = 'client_id';
  static const _eventName = 'event_name';
  static const _subscriptionId = 'subscription_id';
  static const _errorMessage = 'error_message';
  static const _value = 'value';
  static const _id = 'id';
  static const _params = 'params';
  static const _status = 'status';
  static const _result = 'result';
  static const _listeners = 'listeners';

  static const _publishErrorMsg = 'Expected client_id, event_name, and value';
  static const _subscribeErrorMsg = 'Expected client_id, and event_name';
  static const _unsubscribeErrorMsg = 'Expected client_id, and subscription_id';

  const MessageHandler();

  Map<String, dynamic> encodePublishResponseError(String? requestId,
      {String errorMessage = _publishErrorMsg}) {
    return _encodeResponseError(requestId, errorMessage);
  }

  Map<String, dynamic> encodeSubscriptionResponseError(String? requestId,
      {String errorMessage = _subscribeErrorMsg}) {
    return _encodeResponseError(requestId, errorMessage);
  }

  Map<String, dynamic> encodeUnsubscriptionResponseError(String? requestId,
      {String errorMessage = _unsubscribeErrorMsg}) {
    return _encodeResponseError(requestId, errorMessage);
  }

  Map<String, dynamic> encodeUnknownMethodResponseError(
      String? requestId, String method) {
    var unknownMethodErrorMsg =
        'Unrecognized method "$method" or you have omitted id, request_id, method, or params';

    return _encodeResponseError(requestId, unknownMethodErrorMsg);
  }

  Map<String, dynamic> _encodeResponseError(String? requestId, String message) {
    return {
      _status: false,
      _requestId: requestId ?? '',
      _errorMessage: message
    };
  }

  Map<String, dynamic> encodeEventMessage(String? requestId, Object message) {
    return {_status: true, _requestId: requestId ?? '', _result: message};
  }

  Map<String, dynamic> encodeSubscriptionResponseMessage(
      String? requestId, String? subscriptionId, String? clientId) {
    return {
      _status: true,
      _requestId: requestId ?? '',
      _result: {_subscriptionId: subscriptionId, _clientId: clientId}
    };
  }

  (String?, String?) decodeSubscriptionResponseMessage(
      Map<String, Object?> message) {
    var subscriptionId = message[_subscriptionId] as String?;
    var clientId = message[_clientId] as String?;

    return (subscriptionId, clientId);
  }

  Map<String, dynamic> encodeUnsubscriptionResponseMessage(String? requestId) {
    return {_status: true, _requestId: requestId, _result: {}};
  }

  (bool, String?, Object?, String?) decodeUnsubscriptionResponseMessage(
      Map<String, Object?> message) {
    var status = message[_status] as bool? ?? false;
    var requestId = message[_requestId] as String?;
    var result = message[_result];
    var errorMessage = message[_errorMessage] as String?;

    return (status, requestId, result, errorMessage);
  }

  Map<String, Object?> encodePublishResponseMessage2(
      String? requestId, int listeners, String? clientId) {
    return {
      _status: true,
      _requestId: requestId,
      _result: {_listeners: listeners, _clientId: clientId}
    };
  }

  (int, String?) decodePublishResponseMessage(Map<String, Object?> message) {
    var listeners = message[_listeners] as int;
    var clientId = message[_clientId] as String?;

    return (listeners, clientId);
  }

  Map<String, Object?> encodePublishResponseMessage(String? id,
      String? requestId, String? clientId, String? eventName, Object? value) {
    return {
      _id: id,
      _requestId: requestId,
      _method: 'publish',
      _params: {_clientId: clientId, _eventName: eventName, _value: value}
    };
  }

  Map<String, dynamic> encodeResponseMessage(
      String? requestId, Object message) {
    return {_status: true, _requestId: requestId ?? '', _result: message};
  }

  (bool, String?, String?, Object?, String?) decodeResponseMessage(
      Map<String, Object?> message) {
    var id = message[_id] as String?;
    var status = message[_status] as bool? ?? false;
    var requestId = message[_requestId] as String?;
    var result = message[_result];
    var errorMessage = message[_errorMessage] as String?;

    return (status, id, requestId, result, errorMessage);
  }

  (String, String, String, Map<String, Object?>) decodeRequestMessage(
      Map<String, Object?> message) {
    var id = message[_id] as String? ?? '';
    var method = message[_method] as String? ?? '';
    var requestId = message[_requestId] as String? ?? '';
    var params = message[_params] as Map<String, Object?>? ?? {};

    return (id, method, requestId, params);
  }

  Map<String, Object?> encodeSubscriptionRequestMessage(
      String? id, String? requestId, String? clientId, String? eventName) {
    return {
      _id: id,
      _requestId: requestId,
      _method: 'subscribe',
      _params: {_clientId: clientId, _eventName: eventName}
    };
  }

  Map<String, Object?> encodeUnsubscriptionRequestMessage(
      String? id, String? requestId, String? clientId, String? subscriptionId) {
    return {
      _id: id,
      _requestId: requestId,
      _method: 'unsubscribe',
      _params: {_clientId: clientId, _subscriptionId: subscriptionId}
    };
  }

  Map<String, Object?> encodePublishRequestMessage(String? id,
      String? requestId, String? clientId, String? eventName, Object? value) {
    return {
      _id: id,
      _requestId: requestId,
      _method: 'publish',
      _params: {_clientId: clientId, _eventName: eventName, _value: value}
    };
  }

  (String?, String?, String?, Object?) decodeRequestParams(
      Map<String, Object?> params) {
    var clientId = params[_clientId] as String?;
    var eventName = params[_eventName] as String?;
    var value = params[_value];
    var subscriptionId = params[_subscriptionId] as String?;
    return (clientId, eventName, subscriptionId, value);
  }

  Map<String, Object> encodeSendPortResponseMessage(String id) {
    return {_status: true, _id: id};
  }
}
