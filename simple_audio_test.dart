void main() {
  // Simple test to verify audio detection logic
  print('Testing audio file extension detection...');
  
  final audioFormats = [
    'a-237404.mp3',    // The file from your screenshot
    'test.wav', 
    'test.m4a',
    'test.aac',
    'test.ogg',
    'test.flac',
    'test.wma',
    'test.opus',
    'TEST.MP3',        // uppercase
    'song.MP3.bak',    // with suffix
    'test.pdf',        // not audio
    'test.txt',        // not audio
    'test.mp4',        // video, not audio
  ];

  for (final filename in audioFormats) {
    final isAudio = _isAudioFile(filename);
    print('$filename -> isAudio: $isAudio');
  }
}

// Simulate the isAudio getter logic from FileAttachment
bool _isAudioFile(String filename) {
  final String file = filename.toLowerCase();
  return file.endsWith('.mp3') ||
      file.endsWith('.wav') ||
      file.endsWith('.m4a') ||
      file.endsWith('.aac') ||
      file.endsWith('.ogg') ||
      file.endsWith('.flac') ||
      file.endsWith('.wma') ||
      file.endsWith('.opus');
}
