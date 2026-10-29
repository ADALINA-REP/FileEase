import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BeforeAfterSlider extends StatefulWidget {
  final Uint8List beforeBytes;
  final Uint8List afterBytes;
  final String beforeLabel;
  final String afterLabel;

  const BeforeAfterSlider({
    super.key,
    required this.beforeBytes,
    required this.afterBytes,
    this.beforeLabel = 'Original',
    this.afterLabel = 'Résultat',
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _splitPosition = 0.5; // From 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // After (Result) Image - Bottom Layer
              Image.memory(widget.afterBytes, fit: BoxFit.contain),

              // Before (Original) Image - Clipped Layer
              ClipRect(
                clipper: _HorizontalSplitClipper(splitFactor: _splitPosition),
                child: Image.memory(widget.beforeBytes, fit: BoxFit.contain),
              ),

              // Divider Line & Handle
              Positioned(
                left: (width * _splitPosition) - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.compare_arrows_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              // Gesture Detector over entire surface
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _splitPosition = (details.localPosition.dx / width).clamp(
                      0.02,
                      0.98,
                    );
                  });
                },
                onTapDown: (details) {
                  setState(() {
                    _splitPosition = (details.localPosition.dx / width).clamp(
                      0.02,
                      0.98,
                    );
                  });
                },
              ),

              // Labels Overlay
              Positioned(
                top: 10,
                left: 10,
                child: _buildBadge(widget.beforeLabel, Colors.black54),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _buildBadge(
                  widget.afterLabel,
                  AppColors.primaryBlue.withAlpha(200),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitFactor;

  _HorizontalSplitClipper({required this.splitFactor});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * splitFactor, size.height);
  }

  @override
  bool shouldReclip(_HorizontalSplitClipper oldClipper) {
    return oldClipper.splitFactor != splitFactor;
  }
}
