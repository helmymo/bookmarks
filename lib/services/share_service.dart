import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ShareService {
  // Singleton pattern
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  StreamSubscription? _intentDataStreamSubscription;

  /// Listen to shares while the app is already running (in memory)
  void listenToShares(Function(String) onData) {
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          for (var file in value) {
            if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
                // For text/url, the 'path' usually contains the content
                onData(file.path);
            }
          }
        }
      },
      onError: (err) {
        print("getMediaStream error: $err");
      },
    );
  }

  /// Handle "Cold Start" shares
  Future<void> checkForInitialShare(Function(String) onData) async {
    List<SharedMediaFile> sharedFiles = await ReceiveSharingIntent.instance.getInitialMedia();
    if (sharedFiles.isNotEmpty) {
      for (var file in sharedFiles) {
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
             onData(file.path);
        }
      }
      // Reset intent is handled by the plugin usually, or we can look for a reset method if needed.
      // In 1.8.1, `reset()` might be available or automated.
      ReceiveSharingIntent.instance.reset(); 
    }
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}
