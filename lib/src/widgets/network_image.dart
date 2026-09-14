import 'package:chess_srs/src/network/http.dart';
import 'package:chess_srs/src/utils/http_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Like [Image.network], but uses a [HttpNetworkImage] with the globally configured http client.
class HttpNetworkImageWidget extends ConsumerWidget {
  const HttpNetworkImageWidget(
    this.url, {
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
    super.key,
  });

  final String url;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Image(
      image: ResizeImage.resizeIfNeeded(
        cacheWidth,
        cacheHeight,
        HttpNetworkImage(url, ref.watch(defaultClientProvider)),
      ),
      width: width,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
}
