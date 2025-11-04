import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class TempOverlayWidget extends StatefulWidget {
  const TempOverlayWidget({super.key});

  @override
  State<TempOverlayWidget> createState() => _TempOverlayWidgetState();
}

class _TempOverlayWidgetState extends State<TempOverlayWidget> {
  String _temp = "--";

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (mounted && data is String) {
        setState(() {
          _temp = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => FlutterOverlayWindow.closeOverlay(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha((255 * 0.7).round()),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.thermostat_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                "$_temp °C",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
