import 'package:flutter/material.dart';
import '../services/message_service.dart';
import 'dart:ui';
import 'dart:math' as math;

class MessagePopup extends StatefulWidget {
  final String message;
  final MessageType type;
  final VoidCallback onDismiss;

  const MessagePopup({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<MessagePopup> createState() => MessagePopupState();
}

class MessagePopupState extends State<MessagePopup> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expansionAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _contentOpacityAnimation;
  late Animation<double> _slideAnimation;
  bool _isDismissing = false;

  // Store the initial position and final position for better control
  final double _initialY = -60.0; // Starting position (above screen)
  final double _finalY = 0.0;     // Final resting position
  final double _dismissY = -250.0; // Position to animate to when dismissing (above screen)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Main expansion animation with a bounce effect
    _expansionAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuint),
      reverseCurve: const Interval(0.3, 1.0, curve: Curves.easeInQuint),
    );
    
    // Subtle bounce animation that kicks in near the end of expansion
    _bounceAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      reverseCurve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    // Main fade animation
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      reverseCurve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    ));
    
    // Content fade animation that starts after the popup begins expanding
    _contentOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      reverseCurve: const Interval(0.2, 0.6, curve: Curves.easeIn),
    ));
    
    // Simple slide animation - from initial to final position
    _slideAnimation = Tween<double>(
      begin: _initialY,
      end: _finalY,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    _animationController.forward();

    // Listen to animation status to know when the reverse animation completes
    _animationController.addStatusListener(_animationStatusListener);
  }

  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _isDismissing) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _animationController.removeStatusListener(_animationStatusListener);
    _animationController.dispose();
    super.dispose();
  }

  void dismiss() {
    if (!_isDismissing) {
      setState(() {
        _isDismissing = true;
      });
      // Use an even faster duration for the dismissal animation
      _animationController.duration = const Duration(milliseconds: 1000);
      // Start the reverse animation - the status listener will call onDismiss when complete
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Set colors based on message type and theme
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    IconData messageIcon;
    
    switch (widget.type) {
      case MessageType.success:
        backgroundColor = isDarkMode 
            ? const Color(0xFF1A3D2C).withOpacity(0.95) // Dark green background
            : const Color(0xFFE7F6E7).withOpacity(0.95); // Light green background
        borderColor = const Color(0xFF34A853).withOpacity(0.8); // Green border
        iconColor = const Color(0xFF34A853); // Green icon
        messageIcon = Icons.check_circle;
        break;
      case MessageType.error:
        backgroundColor = isDarkMode 
            ? const Color(0xFF3D1A1A).withOpacity(0.95) // Dark red background
            : const Color(0xFFF6E7E7).withOpacity(0.95); // Light red background
        borderColor = const Color(0xFFEA4335).withOpacity(0.8); // Red border
        iconColor = const Color(0xFFEA4335); // Red icon
        messageIcon = Icons.error;
        break;
      case MessageType.warning:
        backgroundColor = isDarkMode 
            ? const Color(0xFF3D2E1A).withOpacity(0.95) // Dark amber background
            : const Color(0xFFF8F4E5).withOpacity(0.95); // Light amber background
        borderColor = const Color(0xFFFBBC05).withOpacity(0.8); // Amber border
        iconColor = const Color(0xFFFBBC05); // Amber icon
        messageIcon = Icons.warning;
        break;
      case MessageType.info:
      default:
        backgroundColor = isDarkMode 
            ? const Color(0xFF1A2A3D).withOpacity(0.95) // Dark blue background
            : const Color(0xFFE7F0F6).withOpacity(0.95); // Light blue background
        borderColor = const Color(0xFF4285F4).withOpacity(0.8); // Blue border
        iconColor = const Color(0xFF4285F4); // Blue icon
        messageIcon = Icons.info;
        break;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 5,
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, _) {
            // Calculate width based on animation value
            // Start as a very small pill and expand to a wider shape
            final screenWidth = MediaQuery.of(context).size.width;
            final minWidth = screenWidth * 0.25; // Initial tiny pill width
            final maxWidth = screenWidth * 0.85; // Expanded width
            
            // Apply both the main expansion and the bounce effect
            final expansionProgress = _expansionAnimation.value;
            final bounceEffect = _bounceAnimation.value * 0.03; // Subtle bounce
            final width = minWidth + ((maxWidth - minWidth) * expansionProgress) * (1 + bounceEffect);
            
            // Calculate text size to determine appropriate bubble height
            final textStyle = TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
              fontFamily: 'Lexend',
            );
            
            // Use a TextPainter to measure the actual text height
            final textSpan = TextSpan(
              text: widget.message,
              style: textStyle,
            );
            
            final textPainter = TextPainter(
              text: textSpan,
              textDirection: TextDirection.ltr,
              maxLines: 100, // Allow many lines to get accurate measurement
            );
            
            // Define fixed padding values for consistent appearance
            final horizontalPadding = 10.0; // Reduced horizontal padding
            final verticalPadding = 16.0; // Keep vertical padding the same
            final iconTextPadding = 12.0; // Space between icon and text
            final iconSize = 24.0;
            final closeIconSize = 20.0;
            
            // Layout with the available width minus icon and padding
            final availableTextWidth = maxWidth - (horizontalPadding * 2) - iconSize - iconTextPadding - closeIconSize - 8;
            
            // Set a consistent text layout during the entire animation
            // Use the final width for text layout to prevent jumping between line counts
            final finalAvailableWidth = screenWidth * 0.85 - (horizontalPadding * 2) - iconSize - iconTextPadding - closeIconSize - 8;
            textPainter.layout(maxWidth: finalAvailableWidth);
            
            // Calculate content height with consistent padding
            final textHeight = textPainter.height;
            final lineHeight = 1.4; // Same as the text style height property
            
            // Total height = text height + top padding + bottom padding
            final contentHeight = math.max(80.0, 
                textHeight * lineHeight + (verticalPadding * 2));
            
            // Calculate height with similar expansion+bounce
            final minHeight = 28.0; // Start very small
            final maxHeight = contentHeight;
            final height = minHeight + ((maxHeight - minHeight) * expansionProgress) * (1 + bounceEffect);

            // Calculate scale
            final scale = 0.85 + (0.15 * expansionProgress);
            
            // Manually calculate border radius - this replaces the BorderRadiusTween animation
            final maxRadius = 40.0;
            final minRadius = 18.0;
            final radius = maxRadius - ((maxRadius - minRadius) * expansionProgress);
            final borderRadius = BorderRadius.circular(radius);

            // Get the content opacity
            final contentOpacity = _contentOpacityAnimation.value;
            final mainOpacity = _opacityAnimation.value;
            
            // Stabilize text layout during animation by using a constant maxLines value
            // This prevents the text from jumping between different line counts
            final int actualLines = (textHeight / (14 * lineHeight)).ceil();
            final int maxLines = actualLines; // Use the actual number of lines needed
            
            // CALCULATE VERTICAL POSITION
            double verticalPosition;
            
            if (_isDismissing) {
              // When dismissing: interpolate from final position (0) to dismiss position (negative value = upward)
              // Custom easing curve for upward dismissal - accelerate quickly at first
              final dismissProgress = Curves.easeInQuad.transform(1.0 - _animationController.value);
              verticalPosition = _finalY + (_dismissY - _finalY) * dismissProgress;
            } else {
              // When appearing: use the slide animation (from initialY to finalY)
              verticalPosition = _slideAnimation.value;
            }
            
            return Transform.translate(
              offset: Offset(0, verticalPosition),
              child: Opacity(
                opacity: mainOpacity,
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: InkWell(
                          onTap: dismiss,
                          borderRadius: borderRadius,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: borderRadius,
                              border: Border.all(color: borderColor, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode 
                                      ? Colors.black.withOpacity(0.3) 
                                      : Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Opacity(
                              opacity: contentOpacity,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      messageIcon,
                                      color: iconColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        widget.message,
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                          fontSize: 14,
                                          fontFamily: 'Lexend',
                                          height: 1.4, // Control line height for consistent spacing
                                        ),
                                        overflow: TextOverflow.visible,
                                        softWrap: true,
                                        maxLines: maxLines,
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: dismiss,
                                      child: Icon(
                                        Icons.close,
                                        color: isDarkMode ? Colors.white70 : Colors.black54,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 