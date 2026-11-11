// Mexe na barra de endereço só no navegador; no Android não faz nada.
export 'url_stub.dart' if (dart.library.js_interop) 'url_web.dart';
