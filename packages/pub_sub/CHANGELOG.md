# Change Log

## 7.0.0

### Breaking changes in 7.0.0

* **Breaking:** `PublishRequest`, `SubscriptionRequest` and `UnsubscriptionRequest` have a `connectionId` getter, and `Adapter` has an `onDisconnect` stream. Both have default implementations, so classes that extend these types keep working, but classes that implement them must add the new members.
* **Breaking:** A trusted connection that sends no client ID uses one ad-hoc ID for all of its requests, so like any other client it is no longer sent the events it publishes itself.
* **Breaking:** An ad-hoc client ID is only valid while the connection it was assigned on is open. Once that connection closes, requests that send the ID are rejected.
* **Breaking:** `JsonRpc2Adapter.close()` stops listening to `clientStream`, which may close its source, such as a `ServerSocket`.

### New in 7.0.0

* An adapter that reports connections lets the server give each trusted connection one ad-hoc client ID and cancel a connection's subscriptions when it closes.
* `IsolateAdapter` and `JsonRpc2Adapter` report connections. `IsolateClient.close()` tells the server it is disconnecting.
* Once an adapter reports a connection on `onDisconnect`, it must not deliver any more requests for that connection.
* The package no longer depends on `collection`.

### Fixes in 7.0.0

* **Server:** A trusted client without a client ID that sends several requests at once is assigned a single ID for its connection, and can unsubscribe from its subscriptions with or without sending that ID.
* **Server:** A closed connection's subscriptions and ad-hoc client ID are removed, instead of being kept forever.
* **Server:** A new subscription is registered as soon as it is accepted, so events published straight afterwards reach it. A subscription that an adapter accepts asynchronously is dropped if its connection closed in the meantime.
* **Server:** `close()` stops handling requests straight away, and completes once all adapters have closed.
* **Server:** Subscription IDs only need to be unique within one adapter, so two adapters that issue the same ID no longer cancel each other's subscriptions.
* **Isolate:** `IsolateAdapter.close()` reports its connections as closed, so a server that keeps running drops their subscriptions.
* **Isolate:** A publish, subscribe or unsubscribe request that is missing a required field gets one error response, naming the missing field, and is not processed further.
* **Isolate:** Publishing a `null` value delivers it to subscribers instead of being reported as an error.
* **JSON-RPC:** A request that arrives after its connection has closed is dropped, instead of leaving a subscription nothing will remove.
* **JSON-RPC:** A subscriber or publisher whose connection has closed no longer stops delivery to other subscribers, leaves the publisher waiting, or causes an uncaught error.
* **JSON-RPC:** `close()` closes every connected client, not only the most recent one, and completes even if a connection ended with an error.
* **JSON-RPC:** A request with a valid `request_id` but a missing or invalid parameter, or one the server fails to handle, gets an error response instead of leaving the client waiting.

## 6.6.0

* Require Dart >= 3.13

## 6.5.0

* Require Dart >= 3.8

## 6.4.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0

## 6.3.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 6.2.0

* Updated `lints` to 3.0.0
* Refactored encode/decode message handling into `MessageHandler`

## 6.1.0

* Updated `uuid` to 4.0.0

## 6.0.0

* Require Dart >= 3.0

## 6.0.0-beta.1

* Require Dart >= 3.0

## 5.0.0

* Require Dart >= 2.17

## 4.0.3

* Fixed license link

## 4.0.2

* Updated README

## 4.0.1

* Updated README

## 4.0.0

* Upgraded from `pendantic` to `lints` linter
* Published as `belatuk_pub_sub` package

## 3.0.2

* Resolved static analysis warnings

## 3.0.1

* Resolved static analysis warnings

## 3.0.0

* Migrated to work with Dart SDK 2.12.x NNBD

## 2.3.0

* Allow `2.x` versions of `stream_channel`.
* Apply `package:pedantic` lints.

## 2.2.0

* Upgrade `uuid`.

## 2.1.0

* Allow for "trusted clients," which are implicitly-registered clients.
This makes using `package:pub_sub` easier, as well making it easier to scale.

## 2.0.0

* Dart 2 updates.
