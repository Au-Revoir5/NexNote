import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final String apiKey;

  GeminiService() : apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  GeminiService.withKey(this.apiKey);

  Future<String> summarize(String text) async {
    if (apiKey.isEmpty) {
      return "Error: Gemini API key not found in .env";
    }

    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey",
      );

      final body = {
        "contents": [
          {
            "parts": [
              {"text": "Summarize this note concisely:\n\n$text"}
            ]
          }
        ]
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      /// Log response for debugging
      print("Gemini raw response: ${response.body}");

      if (response.statusCode != 200) {
        return "Gemini Error ${response.statusCode}: ${response.body}";
      }

      final Map<String, dynamic> json = jsonDecode(response.body);

      /// Extract text safely (Gemini sometimes responds differently)
      final candidates = json["candidates"];
      if (candidates == null || candidates.isEmpty) {
        return "AI returned no candidates.";
      }

      final content = candidates[0]["content"];
      if (content == null) {
        return "AI returned empty content.";
      }

      final parts = content["parts"];
      if (parts == null || parts.isEmpty) {
        return "AI returned no text parts.";
      }

      final textOutput = parts[0]["text"];
      if (textOutput == null) {
        return "AI returned no text.";
      }

      return textOutput;
    } catch (e) {
      print("GeminiService summarize() ERROR: $e");
      return "Failed to generate summary. Please try again.";
    }
  }
}
