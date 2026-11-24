import 'package:flutter/material.dart';

class TvExitDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const TvExitDialog({
    super.key,
    required this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show(BuildContext context, {required VoidCallback onConfirm}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TvExitDialog(
        onConfirm: () {
          Navigator.of(ctx).pop(true);
          onConfirm();
        },
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B0F2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.tv_rounded, color: Colors.amber, size: 24),
          SizedBox(width: 8),
          Text(
            'Exit Demo Mode?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to exit Demo Mode?',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          autofocus: true,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) return Colors.amberAccent;
              return Colors.white70;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) return Colors.white12;
              return Colors.transparent;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return const BorderSide(color: Colors.amberAccent, width: 2);
              }
              return const BorderSide(color: Colors.white24, width: 1);
            }),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: const Text('No', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) return Colors.amber.shade600;
              return Colors.amber.shade800;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.black),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return const BorderSide(color: Colors.white, width: 2);
              }
              return BorderSide.none;
            }),
            elevation: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) return 8;
              return 2;
            }),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          onPressed: onConfirm,
          child: const Text('Yes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
