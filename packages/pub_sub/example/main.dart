import 'dart:io';
import 'dart:isolate';
import 'package:belatuk_pub_sub/isolate.dart';
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';

void main() async {
  // Easily bring up a server.
  var adapter = IsolateAdapter();
  var server = Server([adapter]);

  // You then need to create a client that will connect to the adapter.
  // Every untrusted client in your application should be pre-registered.
  //
  // In the case of Isolates, however, those are always implicitly trusted.
  print("Register Client");
  for (var i = 0; i < Platform.numberOfProcessors - 1; i++) {
    server.registerClient(ClientInfo('client$i'));
  }

  // Start the server.
  server.start();

  // Next, let's start isolates that interact with the server.
  //
  // Fortunately, we can send SendPorts over Isolates, so this is no hassle.
  print("Create Isolate");
  for (var i = 0; i < Platform.numberOfProcessors - 1; i++) {
    await Isolate.spawn(isolateMain, [i, adapter.receivePort.sendPort]);
  }

  // It's possible that you're running your application in the server isolate as well:
  isolateMain([0, adapter.receivePort.sendPort]);
}

void isolateMain(List args) {
  // Isolates are always trusted, so technically we don't need to pass a client iD.
  var client = IsolateClient('client${args[0]}', args[1] as SendPort);

  // The client will connect automatically. In the meantime, we can start subscribing to events.
  client.subscribe('user::logged_in').then((sub) {
    // The `ClientSubscription` class extends `Stream`. Hooray for asynchrony!
    sub.listen((msg) {
      print('Logged in: $msg');
    });
  });
}
