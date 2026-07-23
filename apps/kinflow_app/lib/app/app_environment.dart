enum AppEnvironment {
  dev(
    applicationId: 'me.newlines.kinflow.dev',
    isProduction: false,
    value: 'dev',
  ),
  prod(applicationId: 'me.newlines.kinflow', isProduction: true, value: 'prod');

  const AppEnvironment({
    required this.applicationId,
    required this.isProduction,
    required this.value,
  });

  final String applicationId;
  final bool isProduction;
  final String value;
}
