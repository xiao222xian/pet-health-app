import 'package:flutter/cupertino.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: CupertinoColors.black.withValues(alpha: 0.3),
            child: const Center(child: CupertinoActivityIndicator()),
          ),
      ],
    );
  }
}
