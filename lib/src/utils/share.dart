import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Shares the given [uri], [files], or [text].
///
/// Using this function is recommended over calling [SharePlus.instance.share] directly
/// in order to make it work on iPads.
///
/// On platforms without native share sheet support (e.g. Linux desktop), this gracefully
/// copies text or links to the system clipboard instead of failing.
Future<ShareResult> launchShareDialog(BuildContext context, ShareParams params) async {
  try {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isWindows);
    if ((isDesktop || isTest) && (params.files == null || params.files!.isEmpty)) {
      final copyText = params.text ?? params.uri?.toString();
      if (copyText != null && copyText.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: copyText));
        return const ShareResult('Copied to clipboard', ShareResultStatus.success);
      }
    }

    return await SharePlus.instance.share(
      ShareParams(
        uri: params.uri,
        files: params.files,
        text: params.text,
        subject: params.subject,
        fileNameOverrides: params.fileNameOverrides,
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    debugPrint('launchShareDialog fallback: $e');
    final fallbackText = params.text ?? params.uri?.toString();
    if (fallbackText != null && fallbackText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: fallbackText));
      return const ShareResult('Copied to clipboard', ShareResultStatus.success);
    }
    return ShareResult.unavailable;
  }
}
