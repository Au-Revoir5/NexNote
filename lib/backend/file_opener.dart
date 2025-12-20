import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FileOpener {
  static Future<void> openFile(BuildContext context, String fileUrl, String fileName) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
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