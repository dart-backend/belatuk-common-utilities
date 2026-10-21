import 'dart:async';

import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';
import 'package:test/test.dart';

void main() {
  late _FakeAdapter adapter;
  late Server server;

  setUp(() {
    adapter = _FakeAdapter();
    server = Server([adapter])..start();
  });

  tearDown(() => server.close());

  test(
    'a subscription accepted after its connection closed is dropped',
    () async {
      var subscribe = _FakeSubscriptionRequest('event', 'a');
      adapter.subscribes.add(subscribe);
      await pumpEventQueue();

      adapter.disconnects.add('a');
      await pumpEventQueue();
      subscribe.gate.complete();
      await pumpEventQueue();

      var publish = _FakePublishRequest('event', 'b');
      adapter.publishes.add(publish);
      expect((await publish.response.future).listeners, 0);
    },
  );

  test(
    'a subscription accepted while its connection is open is kept',
    () async {
      var subscribe = _FakeSubscriptionRequest('event', 'a');
      adapter.subscribes.add(subscribe);
      await pumpEventQueue();
      subscribe.gate.complete();
      await pumpEventQueue();

      var publish = _FakePublishRequest('event', 'b');
      adapter.publishes.add(publish);
      expect((await publish.response.future).listeners, 1);
    },
  );

  test('an ad-hoc ID cannot unsubscribe once its connection closed', () async {
    var first = _FakeSubscriptionRequest('event', 'a', async: false);
    adapter.subscribes.add(first);
    var adHocId = await first.accepted.future;

    // Another connection subscribes using the first connection's ad-hoc ID.
    var second = _FakeSubscriptionRequest(
      'event',
      'b',
      clientId: adHocId,
      subscriptionId: 'b1',
      async: false,
    );
    adapter.subscribes.add(second);
    await second.accepted.future;

    adapter.disconnects.add('a');
    await pumpEventQueue();

    var unsubscribe = _FakeUnsubscriptionRequest('b1', 'b', clientId: adHocId);
    adapter.unsubscribes.add(unsubscribe);
    expect(await unsubscribe.result.future, contains('Unrecognized client ID'));
  });

  test('subscription IDs from different adapters do not collide', () async {
    var first = _FakeAdapter();
    var second = _FakeAdapter();
    var server = Server([first, second])..start();
    addTearDown(server.close);

    var subscribeFirst = _FakeSubscriptionRequest(
      'event',
      'a',
      subscriptionId: '1',
      async: false,
    );
    first.subscribes.add(subscribeFirst);
    await subscribeFirst.accepted.future;

    var subscribeSecond = _FakeSubscriptionRequest(
      'event',
      'b',
      subscriptionId: '1',
      async: false,
    );
    second.subscribes.add(subscribeSecond);
    await subscribeSecond.accepted.future;

    var unsubscribe = _FakeUnsubscriptionRequest('1', 'a');
    first.unsubscribes.add(unsubscribe);
    expect(await unsubscribe.result.future, isNull);
  });

  test('requests are not handled after the server closes', () async {
    await server.close();
    var publish = _FakePublishRequest('event', 'b');
    adapter.publishes.add(publish);
    await pumpEventQueue();
    expect(publish.response.isCompleted, isFalse);
  });
}

class _FakeAdapter extends Adapter {
  final publishes = StreamController<PublishRequest>();
  final subscribes = StreamController<SubscriptionRequest>();
  final unsubscribes = StreamController<UnsubscriptionRequest>();
  final disconnects = StreamController<String>();

  @override
  Stream<PublishRequest> get onPublish => publishes.stream;

  @override
  Stream<SubscriptionRequest> get onSubscribe => subscribes.stream;

  @override
  Stream<UnsubscriptionRequest> get onUnsubscribe => unsubscribes.stream;

  @override
  Stream<String> get onDisconnect => disconnects.stream;

  @override
  Future close() => Future.value();

  @override
  void start() {}

  @override
  bool isTrustedPublishRequest(PublishRequest request) => true;

  @override
  bool isTrustedSubscriptionRequest(SubscriptionRequest request) => true;
}

class _FakePublishRequest extends PublishRequest {
  @override
  final String eventName;

  @override
  final String connectionId;

  final response = Completer<PublishResponse>();

  _FakePublishRequest(this.eventName, this.connectionId);

  @override
  String? get clientId => null;

  @override
  Object? get value => null;

  @override
  void accept(PublishResponse response) => this.response.complete(response);

  @override
  void reject(String errorMessage) => response.completeError(errorMessage);
}

/// A subscription request that, unless [async] is `false`, finishes
/// accepting only once [gate] completes.
class _FakeSubscriptionRequest extends SubscriptionRequest {
  @override
  final String eventName;

  @override
  final String connectionId;

  @override
  final String? clientId;

  final String? subscriptionId;
  final bool async;

  final gate = Completer<void>();

  /// Completes with the client ID the server accepted this request for.
  final accepted = Completer<String?>();

  _FakeSubscriptionRequest(
    this.eventName,
    this.connectionId, {
    this.clientId,
    this.subscriptionId,
    this.async = true,
  });

  @override
  FutureOr<Subscription> accept(String? clientId) {
    accepted.complete(clientId);
    var sub = _FakeSubscription(clientId, subscriptionId);
    return async ? gate.future.then((_) => sub) : sub;
  }

  @override
  void reject(String errorMessage) => accepted.completeError(errorMessage);
}

class _FakeUnsubscriptionRequest extends UnsubscriptionRequest {
  @override
  final String subscriptionId;

  @override
  final String connectionId;

  @override
  final String? clientId;

  /// Completes with `null` when accepted, or with the error message.
  final result = Completer<String?>();

  _FakeUnsubscriptionRequest(
    this.subscriptionId,
    this.connectionId, {
    this.clientId,
  });

  @override
  void accept() => result.complete(null);

  @override
  void reject(String errorMessage) => result.complete(errorMessage);
}

class _FakeSubscription extends Subscription {
  @override
  final String? clientId, id;

  _FakeSubscription(this.clientId, this.id);

  @override
  void dispatch(event) {}
}
