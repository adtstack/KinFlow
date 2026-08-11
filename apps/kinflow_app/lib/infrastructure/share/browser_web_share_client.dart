import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:kinflow_app/infrastructure/share/web_household_invite_share_gateway.dart';

final class BrowserWebShareClient implements WebShareClient {
  const BrowserWebShareClient();

  @override
  bool get isSupported => _browserNavigator.has('share');

  @override
  Future<void> share({required String title, required String url}) async {
    final _WebShareNavigator navigator = _WebShareNavigator._(
      _browserNavigator,
    );
    final _WebShareData data = _WebShareData(title: title, url: url);
    await navigator.share(data).toDart;
  }
}

@JS('navigator')
external JSObject get _browserNavigator;

extension type _WebShareNavigator._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> share(_WebShareData data);
}

extension type _WebShareData._(JSObject _) implements JSObject {
  external factory _WebShareData({String title, String url});
}
