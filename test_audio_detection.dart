// Simple test to verify audio detection logic
import 'lib/domain/model/attachment.dart';
import 'lib/domain/model/file.dart';

void main() {
  // Test audio file detection
  final audioFile = FileAttachment(
    id: AttachmentId('test'),
    filename: 'a-237404.mp3',
    original: PlainFile(
      relativeRef: 'test.mp3',
      size: 5500000,
    ),
  );

  print('Testing audio detection for: ${audioFile.filename}');
  print('Is audio: ${audioFile.isAudio}');
  print('Is video: ${audioFile.isVideo}');

  // Test various audio formats
  final audioFormats = [
    'test.mp3',
    'test.wav', 
    'test.m4a',
    'test.aac',
    'test.ogg',
    'test.flac',
    'test.wma',
    'test.opus',
    'test.MP3', // uppercase
    'test.pdf', // not audio
    'test.txt', // not audio
  ];

  for (final format in audioFormats) {
    final testFile = FileAttachment(
      id: AttachmentId('test'),
      filename: format,
      original: PlainFile(
        relativeRef: format,
        size: 1000,
      ),
    );
    print('$format -> isAudio: ${testFile.isAudio}');
  }
}
