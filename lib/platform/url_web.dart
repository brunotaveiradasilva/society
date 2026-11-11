import 'package:web/web.dart' as web;

/// Tira o `?grupo=...` da barra de endereço depois de entrar no grupo, para o
/// atalho da tela de início não ficar preso a um código.
void removeQueryFromUrl() {
  final loc = web.window.location;
  web.window.history.replaceState(null, '', '${loc.pathname}${loc.hash}');
}
