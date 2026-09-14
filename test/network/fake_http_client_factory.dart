import 'package:chess_srs/src/network/http.dart';
import 'package:http/http.dart' as http;

class FakeHttpClientFactory implements HttpClientFactory {
  const FakeHttpClientFactory(this._factory);

  final http.Client Function() _factory;

  @override
  http.Client Function(http.Client client)? get wrapper => throw UnimplementedError();

  @override
  http.Client call() {
    return _factory();
  }
}
