import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/message_popup.dart';

enum MessageType {
  success,
  error,
  info,
  warning,
}

class MessageService {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;
  static bool _isAnimatingOut = false;
  static MessagePopupState? _currentMessageState;

  // Show a message popup at the top of the screen
  static void showMessage(
    BuildContext context, {
    required String message,
    MessageType type = MessageType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any existing message first
    _dismissMessage();

    // Create a new key for each message popup to avoid conflicts
    final messageKey = GlobalKey<MessagePopupState>();

    // Create an overlay entry for the message popup
    _overlayEntry = OverlayEntry(
      builder: (context) => MessagePopup(
        key: messageKey,
        message: message,
        type: type,
        onDismiss: _removeOverlay,
      ),
    );

    // Insert the overlay entry
    Overlay.of(context).insert(_overlayEntry!);
    
    // Store reference to current message state when it's available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentMessageState = messageKey.currentState;
    });

    // Set a timer to automatically dismiss the message
    _timer = Timer(duration, _startDismissAnimation);
  }

  // Start the dismiss animation
  static void _startDismissAnimation() {
    _timer?.cancel();
    _timer = null;

    // Only start the animation if not already animating out
    if (!_isAnimatingOut && _currentMessageState != null) {
      _isAnimatingOut = true;
      _currentMessageState!.dismiss();
    }
  }

  // Actually remove the overlay entry after animation completes
  static void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _currentMessageState = null;
      _isAnimatingOut = false;
    }
  }

  // Dismiss the current message if one exists
  static void _dismissMessage() {
    _timer?.cancel();
    _timer = null;

    if (_currentMessageState != null && !_isAnimatingOut) {
      _startDismissAnimation();
    } else if (_overlayEntry != null) {
      _removeOverlay();
    }
  }
} 