import 'dart:async';
import 'dart:math';

import 'adapter.dart';
import 'client.dart';

import 'publish.dart';
import 'subscription.dart';

/// A server that implements the `pub_sub` protocol.
///
/// It can work using multiple [Adapter]s, to simultaneously
/// serve local and remote clients alike.
class Server {
  final List<Adapter> _adapters = [];
  final Map<String, ClientInfo> _clients = {};
  final _rnd = Random.secure();
  final Map<String?, List<Subscription>> _subscriptions = {};
  final Map<String, String> _connectionClientIds = {};
  final Map<String, Set<Subscription>> _connectionSubscriptions = {};
  final Map<Subscription, (Adapter, String?, String?)> _subscriptionKeys = {};
  final Map<(Adapter, String), Subscription> _subscriptionsById = {};
  final Map<String, int> _pendingAccepts = {};
  final Set<String> _closedWhilePending = {};
  final List<StreamSubscription> _adapterSubscriptions = [];
  bool _started = false;
  bool _closed = false;
  int _adHocIds = 0;

  /// Initialize a server, optionally with a number of [adapters].
  Server([Iterable<Adapter> adapters = const []]) {
    _adapters.addAll(adapters);
  }

  /// Adds a new [Adapter] to adapt incoming clients from a new interface.
  void addAdapter(Adapter adapter) {
    if (_started) {
      throw StateError(
        'You cannot add new adapters after the server has started listening.',
      );
    } else {
      _adapters.add(adapter);
    }
  }

  /// Registers a new client with the server.
  void registerClient(ClientInfo client) {
    if (_started) {
      throw StateError(
        'You cannot register new clients after the server has started listening.',
      );
    } else {
      _clients.putIfAbsent(client.id, () => client);
    }
  }

  /// Disposes of this server, and closes all of its adapters.
  Future close() async {
    _closed = true;
    // Stop handling requests before clearing the state they would act on.
    var cancellations = _adapterSubscriptions.map((s) => s.cancel()).toList();
    _adapterSubscriptions.clear();
    var adapters = List.of(_adapters);
    _adapters.clear();
    _clients.clear();
    _subscriptions.clear();
    _connectionClientIds.clear();
    _connectionSubscriptions.clear();
    _subscriptionKeys.clear();
    _subscriptionsById.clear();
    _pendingAccepts.clear();
    _closedWhilePending.clear();
    await Future.wait([...cancellations, ...adapters.map((a) => a.close())]);
  }

  String _newClientId() {
    // Create an unpredictable-enough ID. The harder it is for an attacker to guess, the better.
    var id =
        'pub_sub::adhoc_client${_rnd.nextDouble()}::${_adHocIds++}:${DateTime.now().millisecondsSinceEpoch * _rnd.nextDouble()}';

    // This client is coming from a trusted source, and can therefore both publish and subscribe.
    _clients[id] = ClientInfo(id);
    return id;
  }

  /// Finds the client a request is made on behalf of.
  ///
  /// A trusted request without a client ID is given an ad-hoc one, which is
  /// shared by every request on the same connection.
  (String?, ClientInfo?) _resolveClient(
    String? requestedId,
    String? connectionId,
    bool isTrusted,
  ) {
    String? clientId;
    if (requestedId?.isNotEmpty == true) {
      clientId = requestedId;
    } else if (!isTrusted) {
      return (null, null);
    } else if (connectionId == null) {
      clientId = _newClientId();
    } else {
      clientId = _connectionClientIds.putIfAbsent(connectionId, _newClientId);
    }
    return (clientId, _clients[clientId]);
  }

  void _addSubscription(
    Adapter adapter,
    Subscription sub,
    String? eventName,
    String? connectionId,
  ) {
    _subscriptions.putIfAbsent(eventName, () => []).add(sub);
    if (connectionId != null) {
      _connectionSubscriptions.putIfAbsent(connectionId, () => {}).add(sub);
    }
    _subscriptionKeys[sub] = (adapter, eventName, connectionId);
    var id = sub.id;
    if (id != null) _subscriptionsById[(adapter, id)] = sub;
  }

  void _removeSubscription(Subscription sub) {
    var keys = _subscriptionKeys.remove(sub);
    if (keys == null) return;
    var (adapter, eventName, connectionId) = keys;
    // Drop emptied collections, so unused event names don't build up.
    var list = _subscriptions[eventName];
    if (list != null && list.remove(sub) && list.isEmpty) {
      _subscriptions.remove(eventName);
    }
    var set = _connectionSubscriptions[connectionId];
    if (set != null && set.remove(sub) && set.isEmpty) {
      _connectionSubscriptions.remove(connectionId);
    }
    var id = sub.id;
    if (id != null && _subscriptionsById[(adapter, id)] == sub) {
      _subscriptionsById.remove((adapter, id));
    }
  }

  /// Cancels the subscriptions and ad-hoc client ID of a closed connection.
  void _disconnect(String connectionId) {
    if (_pendingAccepts.containsKey(connectionId)) {
      _closedWhilePending.add(connectionId);
    }
    for (var sub in List.of(_connectionSubscriptions[connectionId] ?? {})) {
      _removeSubscription(sub);
    }
    var clientId = _connectionClientIds.remove(connectionId);
    if (clientId != null) _clients.remove(clientId);
  }

  void start() {
    if (_adapters.isEmpty) {
      throw StateError(
        'Cannot start a SyncServer that has no adapters attached.',
      );
    } else if (_started) {
      throw StateError('A SyncServer may only be started once.');
    }

    _started = true;

    for (var adapter in _adapters) {
      adapter.start();
    }

    for (var adapter in _adapters) {
      // Handle publishes
      _adapterSubscriptions.add(
        adapter.onPublish.listen((rq) {
          var (clientId, client) = _resolveClient(
            rq.clientId,
            rq.connectionId,
            adapter.isTrustedPublishRequest(rq),
          );

          if (client == null) {
            rq.reject('Unrecognized client ID "${clientId ?? '<missing>'}".');
          } else if (!client.canPublish) {
            rq.reject('You are not allowed to publish events.');
          } else {
            var listeners =
                _subscriptions[rq.eventName]
                    ?.where((s) => s.clientId != clientId)
                    .toList() ??
                [];

            for (var listener in listeners) {
              listener.dispatch(rq.value);
            }

            rq.accept(PublishResponse(listeners.length, clientId));
          }
        }),
      );

      // Listen for incoming subscriptions
      _adapterSubscriptions.add(
        adapter.onSubscribe.listen((rq) {
          var (clientId, client) = _resolveClient(
            rq.clientId,
            rq.connectionId,
            adapter.isTrustedSubscriptionRequest(rq),
          );

          if (client == null) {
            rq.reject('Unrecognized client ID "${clientId ?? '<missing>'}".');
          } else if (!client.canSubscribe) {
            rq.reject('You are not allowed to subscribe to events.');
          } else {
            var connectionId = rq.connectionId;

            // Register synchronously when possible, so that no publish can slip
            // in between accepting the subscription and recording it.
            var sub = rq.accept(clientId);
            if (sub is Subscription) {
              _addSubscription(adapter, sub, rq.eventName, connectionId);
            } else if (connectionId == null) {
              sub.then((sub) {
                if (!_closed) {
                  _addSubscription(adapter, sub, rq.eventName, null);
                }
              });
            } else {
              // Remember whether the connection closes while this is pending.
              _pendingAccepts.update(
                connectionId,
                (n) => n + 1,
                ifAbsent: () => 1,
              );
              sub
                  .then((sub) {
                    if (!_closed &&
                        !_closedWhilePending.contains(connectionId)) {
                      _addSubscription(
                        adapter,
                        sub,
                        rq.eventName,
                        connectionId,
                      );
                    }
                  })
                  .whenComplete(() {
                    var pending = _pendingAccepts[connectionId];
                    if (pending == null) return;
                    if (pending > 1) {
                      _pendingAccepts[connectionId] = pending - 1;
                    } else {
                      _pendingAccepts.remove(connectionId);
                      _closedWhilePending.remove(connectionId);
                    }
                  });
            }
          }
        }),
      );

      // Unregister subscriptions on unsubscribe
      _adapterSubscriptions.add(
        adapter.onUnsubscribe.listen((rq) {
          var subscriptionId = rq.subscriptionId;
          var toRemove = subscriptionId == null
              ? null
              : _subscriptionsById[(adapter, subscriptionId)];

          // A client that sent no ID may be using its connection's ad-hoc one.
          var clientId = rq.clientId?.isNotEmpty == true
              ? rq.clientId
              : _connectionClientIds[rq.connectionId];

          if (toRemove == null) {
            rq.reject('The specified subscription does not exist.');
          } else if (!_clients.containsKey(clientId)) {
            rq.reject('Unrecognized client ID "${clientId ?? '<missing>'}".');
          } else if (toRemove.clientId != clientId) {
            rq.reject('That is not your subscription to cancel.');
          } else {
            _removeSubscription(toRemove);
            rq.accept();
          }
        }),
      );

      _adapterSubscriptions.add(adapter.onDisconnect.listen(_disconnect));
    }
  }
}
