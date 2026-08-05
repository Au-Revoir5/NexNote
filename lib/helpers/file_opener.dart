import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nexnote/main.dart';

class FileOpener {
  static void _showSnack(String message, {Color color = Colors.black}) {
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // -------------------------------
  // 🔽 DOWNLOAD TO DOWNLOADS FOLDER
  // -------------------------------
  static Future<bool> _handleStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.storage.status;

    // If permission exists (Android ≤ 12)
    if (status.isGranted) return true;

    // Try requesting (Android ≤ 12)
    final result = await Permission.storage.request();

    // Android 13+ will still return denied → ALLOW anyway
    return result.isGranted || result.isDenied;
  }

  static Future<void> downloadFileWithProgress(
    BuildContext context,
    String fileUrl,
    String fileName,
  ) async {
    // Android < 13 permission
    final allowed = await _handleStoragePermission();
    if (!allowed) {
      _showSnack('Storage permission required to download', color: Colors.red);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;

      final publicIndex = segments.indexOf('public');
      final signIndex = segments.indexOf('sign');
      final baseIndex = publicIndex != -1 ? publicIndex : signIndex;

      if (baseIndex == -1 || baseIndex + 2 >= segments.length) {
        throw Exception('Invalid Supabase file URL');
      }

      final filePath = segments.sublist(baseIndex + 2).join('/');

      // Create signed URL
      final signedUrl = await supabase.storage
          .from('notes')
          .createSignedUrl(filePath, 3600);

      // Downloads directory
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final file = File('${downloadDir.path}/$fileName');

      final request = http.Request('GET', Uri.parse(signedUrl));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final progress = ValueNotifier<double>(0);

      // Progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => _DownloadProgressDialog(progress),
      );

      final sink = file.openWrite();

      response.stream.listen(
        (chunk) {
          receivedBytes += chunk.length;
          sink.add(chunk);

          if (totalBytes != 0) {
            progress.value = receivedBytes / totalBytes;
          }
        },
        onDone: () async {
          await sink.close();
          Navigator.pop(context);

          _showSnack('Downloaded to Downloads/$fileName', color: Colors.green);
        },
        onError: (e) async {
          await sink.close();
          Navigator.pop(context);
          _showSnack('Download failed', color: Colors.red);
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (context.mounted) {
        _showSnack('Download error', color: Colors.red);
      }
    }
  }

  static Future<void> openFile(
    BuildContext context,
    String fileUrl,
    String fileName,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get signed URL from Supabase
      final supabase = Supabase.instance.client;
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;

      // Supabase storage URLs:
      // /storage/v1/object/public/<bucket>/<path>
      // /storage/v1/object/sign/<bucket>/<path>

      final publicIndex = pathSegments.indexOf('public');
      final signIndex = pathSegments.indexOf('sign');

      final baseIndex = publicIndex != -1 ? publicIndex : signIndex;

      if (baseIndex == -1 || baseIndex + 1 >= pathSegments.length) {
        throw Exception('Invalid Supabase file URL');
      }

      final filePath = pathSegments.sublist(baseIndex + 2).join('/');

      // Create signed URL
      final signedUrl = await supabase.storage
          .from('notes')
          .createSignedUrl(filePath, 3600); // Valid for 1 hour

      // Download file
      final response = await http.get(Uri.parse(signedUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download file');
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');

      // Save file
      await file.writeAsBytes(response.bodyBytes);

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Open file with default app
      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.pop(context);

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  const _DownloadProgressDialog(this.progress);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading…'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, __) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          );
        },
      ),
    );
  }
}
