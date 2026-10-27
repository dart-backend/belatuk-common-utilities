# Belatuk Pub Sub

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_pub_sub?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/pub_sub/LICENSE)

A publish/subscribe library for keeping application instances in sync, such as several isolates of one server, or several processes connected over a network. A central server passes events between clients, and checks every request against a list of known clients and their permissions.

## Installation

```yaml
dependencies:
  belatuk_pub_sub: ^7.0.0
```

## Overview

A `Server` passes events between clients. It receives their requests through one or more *adapters*, each of which serves clients over one medium. A single server can serve clients in other isolates and clients over the network at the same time.

| Library | Contents |
| --- | --- |
| `package:belatuk_pub_sub/belatuk_pub_sub.dart` | `Server`, `ClientInfo`, the `Client` and `Adapter` interfaces, and `PubSubException` |
| `package:belatuk_pub_sub/isolate.dart` | `IsolateAdapter` and `IsolateClient`, which communicate through `SendPort`s |
| `package:belatuk_pub_sub/json_rpc_2.dart` | `JsonRpc2Adapter` and `JsonRpc2Client`, which communicate with JSON-RPC 2.0 over any `StreamChannel<String>`, such as a WebSocket |

```dart
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';
import 'package:belatuk_pub_sub/isolate.dart';

void main() async {
  var adapter = IsolateAdapter();
  var server = Server([adapter])..start();

  var alice = IsolateClient(null, adapter.receivePort.sendPort);
  var bob = IsolateClient(null, adapter.receivePort.sendPort);

  var subscription = await bob.subscribe('greeting');
  await alice.publish('greeting', 'Hello, Bob!');
  print(await subscription.first); // Hello, Bob!

  await alice.close();
  await bob.close();
  await server.close();
}
```

`addAdapter` adds another adapter, and `start` starts them all and begins handling requests. Both adapters and clients must be added before the server starts. `close` closes the server and all its adapters.

## Publishing and subscribing

Every client implements the same `Client` interface:

| Method | Effect |
| --- | --- |
| `publish(eventName, value)` | Sends `value` to every current subscriber to `eventName`, except subscribers with the publisher's own client ID. Completes once the server has accepted the event |
| `subscribe(eventName)` | Completes with a `ClientSubscription`, which is a `Stream` of the values published to `eventName` |
| `close()` | Closes the client and all its subscriptions |

Call `unsubscribe` on a `ClientSubscription` to tell the server to stop sending events to it. Its stream then closes.

```dart
var subscription = await client.subscribe('user::logged_in');
subscription.listen((user) => print('Logged in: $user'));

// Later:
await subscription.unsubscribe();
```

Events are only sent to subscriptions that exist when they are published. They are not stored, so a client that subscribes later does not receive earlier events.

When the server rejects a request, the `Future` completes with a `PubSubException`, whose `message` gives the reason.

## Clients and permissions

Each request names the client it is made on behalf of, by its client ID. The server only accepts IDs that were registered with `registerClient` before it started. A `ClientInfo` can also deny a client permission to publish or to subscribe.

```dart
var server = Server([adapter])
  ..registerClient(const ClientInfo('web-1'))
  // This client can subscribe, but not publish.
  ..registerClient(const ClientInfo('dashboard', canPublish: false))
  // This client can publish, but not subscribe.
  ..registerClient(const ClientInfo('audit-log', canSubscribe: false))
  ..start();

var dashboard = IsolateClient('dashboard', adapter.receivePort.sendPort);

try {
  await dashboard.publish('user::logged_in', 'Mary');
} on PubSubException catch (e) {
  print(e.message); // You are not allowed to publish events.
}
```

Client IDs are the only form of authentication, so keep them secret. Anyone who knows a client ID can publish and subscribe as that client.

### Trusted clients

A client can pass `null` as its client ID if its adapter trusts it. The server then gives it an ad-hoc ID, with permission to publish and subscribe, and the client's `clientId` getter returns that ID after its first request. All requests sent over the same connection share one ad-hoc ID, which stops working when the connection closes.

| Adapter | Trusted |
| --- | --- |
| `IsolateAdapter` | Always, since its clients run in the same process |
| `JsonRpc2Adapter` | Only if created with `isTrusted: true` |

A client that sends an ID must use a registered one, even on a trusted adapter.

## Isolates

`IsolateAdapter` receives requests on its `receivePort`. Send `adapter.receivePort.sendPort` to each isolate, and create an `IsolateClient` there. The client connects to the server on its own, and requests made before the connection completes wait for it.

```dart
import 'dart:isolate';

import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';
import 'package:belatuk_pub_sub/isolate.dart';

void main() async {
  var adapter = IsolateAdapter();
  var server = Server([adapter])..start();

  var client = IsolateClient(null, adapter.receivePort.sendPort);
  var subscription = await client.subscribe('job::done');

  for (var i = 1; i <= 3; i++) {
    await Isolate.spawn(worker, (i, adapter.receivePort.sendPort));
  }

  await for (var message in subscription.take(3)) {
    print(message); // Worker 1 finished, and so on, in any order.
  }

  await client.close();
  await server.close();
}

Future<void> worker((int, SendPort) args) async {
  var (id, serverPort) = args;
  var client = IsolateClient(null, serverPort);
  await client.publish('job::done', 'Worker $id finished');
  await client.close();
}
```

Published values are sent between isolates, so they must be objects that a `SendPort` can send.

## JSON-RPC 2.0

`JsonRpc2Adapter` serves clients over any `StreamChannel<String>`, using [`package:json_rpc_2`](https://pub.dev/packages/json_rpc_2). It takes a `Stream` of channels, one for each client that connects. Published values must be encodable as JSON.

This example serves clients over WebSockets with `dart:io`. It also needs [`package:stream_channel`](https://pub.dev/packages/stream_channel) in your dependencies.

```dart
import 'dart:async';
import 'dart:io';

import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';
import 'package:belatuk_pub_sub/json_rpc_2.dart';
import 'package:stream_channel/stream_channel.dart';

Future<Server> startServer() async {
  var channels = StreamController<StreamChannel<String>>();
  var httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);

  httpServer.listen((request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      var socket = await WebSocketTransformer.upgrade(request);
      channels.add(StreamChannel<dynamic>(socket, socket).cast<String>());
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  });

  return Server([JsonRpc2Adapter(channels.stream)])
    ..registerClient(const ClientInfo('worker-secret'))
    ..start();
}

Future<Client> connect() async {
  var socket = await WebSocket.connect('ws://localhost:8080');
  var channel = StreamChannel<dynamic>(socket, socket).cast<String>();
  return JsonRpc2Client('worker-secret', channel);
}
```

Closing a `JsonRpc2Adapter`, or the server it belongs to, closes every client connection, and cancels its subscription to the stream of channels. That may close the stream's source, such as a `ServerSocket`.

### Wire protocol

Clients in other languages can connect by sending JSON-RPC 2.0 notifications. Each request is a notification named `publish`, `subscribe` or `unsubscribe`, with a `request_id` chosen by the client.

| Method | Parameters |
| --- | --- |
| `publish` | `request_id`, `client_id`, `event_name`, `value` |
| `subscribe` | `request_id`, `client_id`, `event_name` |
| `unsubscribe` | `request_id`, `client_id`, `subscription_id` |

`client_id` can be left out on a trusted adapter. The server responds with a notification whose method name is the `request_id`:

```json
{"jsonrpc": "2.0", "method": "subscribe", "params": {"request_id": "1", "client_id": "web-1", "event_name": "news"}}
{"jsonrpc": "2.0", "method": "1", "params": {"status": true, "request_id": "1", "subscription_id": "...", "client_id": "web-1"}}
```

A successful `publish` response has a `result` with `listeners`, the number of subscriptions the event was sent to, and `client_id`. A failed request has `status` set to `false` and an `error_message`. Events arrive as notifications named `event`:

```json
{"jsonrpc": "2.0", "method": "event", "params": {"event_name": "news", "value": {"headline": "..."}}}
```

## Custom adapters

To serve clients over another medium, extend `Adapter`. An adapter delivers requests on its `onPublish`, `onSubscribe` and `onUnsubscribe` streams, and decides which requests are trusted.

An adapter that tracks connections should give each request the `connectionId` of the connection it arrived on, and report each closed connection on `onDisconnect`. The server then removes that connection's subscriptions and ad-hoc client ID. Without connection IDs, each trusted request that sends no client ID is given a new ad-hoc ID, and ad-hoc IDs are kept until the server closes.

## Limitations

Client IDs are sent with every request. Over a network, use an encrypted connection, such as `wss://`, so that they cannot be read and reused.

Neither client reconnects on its own. After a connection is lost, create a new client and subscribe again.

## Upgrading from 6.x

Version 7.0.0 gives a trusted connection without a client ID a single ad-hoc ID, so such a client no longer receives the events it publishes itself, and the ID stops working when the connection closes. Classes that implement, rather than extend, `Adapter` or the request classes must add the new `onDisconnect` and `connectionId` members. See the [changelog](CHANGELOG.md) for the full list.
