import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:test/widgets/message/message_bubble.dart';

void main() {
  // Initialize Flutter binding for unit tests that access Icons/material
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BubbleHelpers', () {
    test('getFileName extracts filename from URL', () {
      expect(
        BubbleHelpers.getFileName('https://example.com/path/to/file.pdf'),
        'file.pdf',
      );
      expect(
        BubbleHelpers.getFileName('https://example.com/file.pdf?token=abc'),
        'file.pdf',
      );
      expect(
        BubbleHelpers.getFileName('https://example.com/simple'),
        'simple',
      );
    });

    test('getFileExtension returns correct extension', () {
      expect(
        BubbleHelpers.getFileExtension('https://example.com/doc.pdf'),
        'pdf',
      );
      expect(
        BubbleHelpers.getFileExtension('https://example.com/noext'),
        'file',
      );
      expect(
        BubbleHelpers.getFileExtension('https://example.com/archive.tar.gz'),
        'gz',
      );
    });

    test('getFileIconFromName returns correct icon for known types', () {
      expect(
        BubbleHelpers.getFileIconFromName('doc.pdf'),
        Icons.picture_as_pdf,
      );
      expect(
        BubbleHelpers.getFileIconFromName('sheet.xlsx'),
        Icons.table_chart,
      );
      expect(
        BubbleHelpers.getFileIconFromName('presentation.pptx'),
        Icons.slideshow,
      );
      expect(
        BubbleHelpers.getFileIconFromName('archive.zip'),
        Icons.folder_zip,
      );
      expect(
        BubbleHelpers.getFileIconFromName('unknown.xyz'),
        Icons.insert_drive_file,
      );
    });

    test('formatFileSize formats bytes correctly', () {
      expect(BubbleHelpers.formatFileSize(500), '500 B');
      expect(BubbleHelpers.formatFileSize(1024), '1.0 KB');
      expect(BubbleHelpers.formatFileSize(1536), '1.5 KB');
      expect(BubbleHelpers.formatFileSize(1048576), '1.0 MB');
      expect(BubbleHelpers.formatFileSize(1572864), '1.5 MB');
    });

    test('formatDuration formats Duration correctly', () {
      expect(
        BubbleHelpers.formatDuration(const Duration(seconds: 0)),
        '00:00',
      );
      expect(
        BubbleHelpers.formatDuration(const Duration(seconds: 5)),
        '00:05',
      );
      expect(
        BubbleHelpers.formatDuration(const Duration(minutes: 2, seconds: 30)),
        '02:30',
      );
      expect(
        BubbleHelpers.formatDuration(const Duration(hours: 1, minutes: 5)),
        '05:00',
      );
    });
  });
}
