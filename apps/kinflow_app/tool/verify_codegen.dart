import 'dart:io';

Future<void> main() async {
  final Map<String, List<int>> before = await _generatedFiles();
  final ProcessResult generation = await Process.run(
    Platform.resolvedExecutable,
    <String>['run', 'build_runner', 'build'],
  );

  stdout.write(generation.stdout);
  stderr.write(generation.stderr);
  if (generation.exitCode != 0) {
    exitCode = generation.exitCode;
    return;
  }

  final Map<String, List<int>> after = await _generatedFiles();
  final Set<String> allPaths = <String>{...before.keys, ...after.keys};
  final List<String> changedPaths =
      allPaths
          .where((String path) => !_sameBytes(before[path], after[path]))
          .toList()
        ..sort();

  if (changedPaths.isNotEmpty) {
    stderr.writeln('Generated code drift detected:');
    for (final String path in changedPaths) {
      stderr.writeln('- $path');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Generated code drift check passed (${after.length} files).');
}

Future<Map<String, List<int>>> _generatedFiles() async {
  final List<File> files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (File file) =>
                file.path.endsWith('.g.dart') ||
                file.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((File left, File right) => left.path.compareTo(right.path));

  final Map<String, List<int>> contents = <String, List<int>>{};
  for (final File file in files) {
    contents[file.path] = await file.readAsBytes();
  }
  return contents;
}

bool _sameBytes(List<int>? left, List<int>? right) {
  if (left == null || right == null || left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
