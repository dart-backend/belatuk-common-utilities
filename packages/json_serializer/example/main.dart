import 'package:belatuk_json_serializer/belatuk_json_serializer.dart' as god;

class A {
  String foo;
  A(this.foo);
}

class B {
  String hello;
  late A nested;
  B(this.hello, String foo) {
    nested = A(foo);
  }
}

void main() {
  print(god.serialize(B("world", "bar")));
}
