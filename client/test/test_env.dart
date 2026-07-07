import 'dart:io';

class TestEnv {
  const TestEnv({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;
}

TestEnv? readTestEnvOrNull() {
  final envFile = _findEnvFile();
  if (envFile == null) {
    return null;
  }

  final values = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
      continue;
    }
    final separator = trimmed.indexOf('=');
    values[trimmed.substring(0, separator)] = trimmed.substring(separator + 1);
  }

  final baseUrl = values['FLASH_IM_API_BASE_URL']?.trim();
  final token = values['FLASH_IM_TOKEN']?.trim();
  if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
    return null;
  }

  return TestEnv(baseUrl: baseUrl, token: token);
}

File? _findEnvFile() {
  for (final path in const [
    'test/.env',
    '../../test/.env',
    '../../../test/.env',
  ]) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }
  return null;
}
