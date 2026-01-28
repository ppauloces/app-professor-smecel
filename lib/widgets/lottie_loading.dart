import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';

class LottieLoading extends StatelessWidget {
  final String? message;
  final double height;

  const LottieLoading({
    super.key,
    this.message,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: height,
            child: DotLottieLoader.fromAsset(
              'assets/svg/loading.lottie',
              frameBuilder: (context, dotlottie) {
                if (dotlottie == null || dotlottie.animations.isEmpty) {
                  return const SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return Lottie.memory(
                  dotlottie.animations.values.first,
                  fit: BoxFit.contain,
                  repeat: true,
                  imageProviderFactory: (asset) {
                    final bytes = dotlottie.images[asset.fileName];
                    if (bytes == null) return null;
                    return MemoryImage(bytes);
                  },
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
