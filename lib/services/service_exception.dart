class AppServiceException implements Exception {
  final String message;

  const AppServiceException(this.message);

  @override
  String toString() => message;
}
