import 'package:flutter/foundation.dart' show kIsWeb;

const _proxyBase = 'https://xfskhdirwocfsfmcahkf.supabase.co/functions/v1/image-proxy';

String resolveImageUrl(String url) {
  if (!kIsWeb) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host.toLowerCase();
  if (host == 'ventoz.nl' || host == 'www.ventoz.nl' ||
      host == 'ventoz.com' || host == 'www.ventoz.com') {
    return '$_proxyBase?url=${Uri.encodeComponent(url)}';
  }
  return url;
}
