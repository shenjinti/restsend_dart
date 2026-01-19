import 'dart:math';
import 'package:logging/logging.dart';

/// Format date helper
DateTime? formatDate(dynamic date) {
  if (date == null) return null;
  if (date is String) {
    return DateTime.parse(date);
  }
  if (date is DateTime) {
    return date;
  }
  return null;
}

/// Generate random text
String randText([int length = 8]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();
  return 'j${List.generate(length, (index) => chars[random.nextInt(chars.length)]).join()}';
}

/// Logger instance
final logger = Logger('restsend_dart');

/// Initialize logger
void initLogger({Level level = Level.INFO}) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}
