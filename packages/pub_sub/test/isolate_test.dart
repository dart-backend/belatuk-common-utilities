import 'dart:async';
import 'dart:isolate';

import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';
import 'package:belatuk_pub_sub/isolate.dart';
import 'package:test/test.dart';

void main() {
  late Server server;
  late Client client1, client2, client3;
  late IsolateClient trustedClient;
  late IsolateAdapter adapter;

  setUp(() async {
    adapter = IsolateAdapter();
    client1 = IsolateClient(
      'isolate_test::secret',
      adapter.receivePort.sendPort,
    );
    client2 = IsolateClient(
      'isolate_test::secret2',
      adapter.receivePort.sendPort,
    );
    client3 = IsolateClient(
      'isolate_test::secret3',
      adapter.receivePort.sendPort,
    );
    trustedClient = IsolateClient(null, adapter.receivePort.sendPort);

    server = Server([adapter])
      ..registerClient(const ClientInfo('isolate_test::secret'))
      ..registerClient(const ClientInfo('isolate_test::secret2'))
      ..registerClient(const ClientInfo('isolate_test::secret3'))
      ..registerClient(
        const ClientInfo('isolate_test::no_publish', canPublish: false),
      )
      ..registerClient(
        const ClientInfo('isolate_test::no_subscribe', canSubscribe: false),
      )
      ..start();

    var sub = await client3.subscribe('foo');
    sub.listen((data) {
      print('Client3 caught foo: $data');
    });
  });

  tearDown(() {
    Future.wait([
      server.close(),
      client1.close(),
      client2.close(),
      client3.close(),
      trustedClient.close(),
    ]);
  });

  group('trusted', () {
    test('can publish', () async {
      await trustedClient.publish('hey', 'bye');
      expect(trustedClient.clientId, isNotNull);
    });
    test('can sub/unsub', () async {
      String? clientId;
      await trustedClient.publish('heyaaa', 'byeaa');
      expect(clientId = trustedClient.clientId, isNotNull);

      var sub = await trustedClient.subscribe('yeppp');
      expect(trustedClient.clientId, clientId);

      await sub.unsubscribe();
      expect(trustedClient.clientId, clientId);
    });
    test('concurrent requests share one client id', () async {
      var connection = _RawConnection(adapter.receivePort.sendPort);
      await connection.connect();
      connection.send('subscribe', '1', {'event_name': 'a'});
      connection.send('subscribe', '2', {'event_name': 'b'});

      var first = await connection.next();
      var second = await connection.next();
      expect(first['result']['client_id'], isNotNull);
      expect(second['result']['client_id'], first['result']['client_id']);
      await connection.close();
    });
  });

  test('can publish a null value', () async {
    var sub = await client2.subscribe('nullable');
    await client1.publish('nullable', null);
    expect(await sub.first, isNull);
  });

  test('subscribers receive published events', () async {
    var sub = await client2.subscribe('foo');
    await client1.publish('foo', 'bar');
    expect(await sub.first, 'bar');
  });

  test('subscribers are not sent their own events', () async {
    var sub = await client1.subscribe('foo');
    await client1.publish(
      'foo',
      '<this should never be sent to client1, because client1 sent it.>',
    );
    await sub.unsubscribe();
    expect(await sub.isEmpty, isTrue);
  });

  test('can unsubscribe', () async {
    var sub = await client2.subscribe('foo');
    await client1.publish('foo', 'bar');
    await sub.unsubscribe();
    await client1.publish('foo', '<client2 will not catch this!>');
    expect(await sub.length, 1);
  });

  group('isolate_server', () {
    test('reject unknown client id', () async {
      try {
        var client = IsolateClient(
          'isolate_test::invalid',
          adapter.receivePort.sendPort,
        );
        await client.publish('foo', 'bar');
        throw 'Invalid client ID\'s should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });

    test('reject unprivileged publish', () async {
      try {
        var client = IsolateClient(
          'isolate_test::no_publish',
          adapter.receivePort.sendPort,
        );
        await client.publish('foo', 'bar');
        throw 'Unprivileged publishes should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });

    test('reject unprivileged subscribe', () async {
      try {
        var client = IsolateClient(
          'isolate_test::no_subscribe',
          adapter.receivePort.sendPort,
        );
        await client.subscribe('foo');
        throw 'Unprivileged subscribes should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });

    test(
      'invalid requests get exactly one error and are not processed',
      () async {
        var connection = _RawConnection(adapter.receivePort.sendPort);
        await connection.connect();

        for (var method in ['publish', 'subscribe', 'unsubscribe']) {
          connection.send(method, method, {});
        }
        // Responses arrive in order, so a second response to any of the
        // requests above would arrive before this one.
        connection.send('sentinel', 'sentinel', {});

        for (var requestId in [
          'publish',
          'subscribe',
          'unsubscribe',
          'sentinel',
        ]) {
          var response = await connection.next();
          expect(response['request_id'], requestId);
          expect(response['status'], isFalse);
        }
        await connection.close();
      },
    );

    test('a client without an ID can unsubscribe on its connection', () async {
      var connection = _RawConnection(adapter.receivePort.sendPort);
      await connection.connect();

      connection.send('subscribe', 's', {'event_name': 'adhoc'});
      var subscribed = await connection.next();
      expect(subscribed['status'], isTrue);

      connection.send('unsubscribe', 'u', {
        'subscription_id': subscribed['result']['subscription_id'],
      });
      var unsubscribed = await connection.next();
      expect(unsubscribed['request_id'], 'u');
      expect(unsubscribed['status'], isTrue);
      await connection.close();
    });

    test('closing the adapter reports its connections as closed', () async {
      var adapter = IsolateAdapter()..start();
      var disconnects = adapter.onDisconnect.toList();
      var connection = _RawConnection(adapter.receivePort.sendPort);
      await connection.connect();

      await adapter.close();
      expect(await disconnects, [connection.id]);
      await connection.close();
    });

    test('a closed client\'s subscriptions are cancelled', () async {
      var subscriber = IsolateClient(
        'isolate_test::secret2',
        adapter.receivePort.sendPort,
      );
      await subscriber.subscribe('gone');
      await subscriber.close();

      var publisher = _RawConnection(adapter.receivePort.sendPort);
      await publisher.connect();
      publisher.send('publish', 'p', {
        'client_id': 'isolate_test::secret',
        'event_name': 'gone',
        'value': 1,
      });
      var response = await publisher.next();
      expect(response['result'], containsPair('listeners', 0));
      await publisher.close();
    });
  });
}

/// A connection that sends raw messages to an [IsolateAdapter].
class _RawConnection {
  final SendPort server;
  final ReceivePort _port = ReceivePort();
  late final StreamIterator<Object?> _messages = StreamIterator(_port);
  String? _id;

  _RawConnection(this.server);

  /// The connection ID the adapter assigned to this connection.
  String? get id => _id;

  Future<void> connect() async {
    server.send(_port.sendPort);
    _id = (await next())['id'] as String;
  }

  void send(String method, String requestId, Map<String, Object?> params) {
    server.send(<String, Object?>{
      'id': _id,
      'request_id': requestId,
      'method': method,
      'params': params,
    });
  }

  Future<Map> next() async {
    if (!await _messages.moveNext()) throw StateError('Connection closed.');
    return _messages.current as Map;
  }

  Future<void> close() => _messages.cancel();
}
