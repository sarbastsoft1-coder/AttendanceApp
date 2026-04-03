Future<void> downloadTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/plain;charset=utf-8',
}) async {
  throw UnsupportedError('Browser download is only available on web.');
}
