Uri? trustedExternalHttpsUri(Uri uri) {
  return uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          uri.query.isEmpty &&
          uri.fragment.isEmpty
      ? uri
      : null;
}

Uri? trustedPublicDocumentUri(Uri baseUri, String documentPath) {
  if (!documentPath.startsWith('/') ||
      documentPath.contains('?') ||
      documentPath.contains('#')) {
    return null;
  }
  return trustedExternalHttpsUri(
    Uri(
      scheme: baseUri.scheme,
      userInfo: baseUri.userInfo,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: documentPath,
    ),
  );
}
