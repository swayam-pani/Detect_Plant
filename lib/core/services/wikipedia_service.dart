import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final wikipediaServiceProvider = Provider((ref) => WikipediaService());

class WikipediaService {
  static const String _baseUrl =
      'https://en.wikipedia.org/api/rest_v1/page/summary/';

  Future<Map<String, dynamic>?> getDiseaseInfo(String diseaseName) async {
    try {
      // Fetching from Wikipedia API
      final url = Uri.parse('$_baseUrl${Uri.encodeComponent(diseaseName)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'title': data['title'],
          'extract': data['extract'],
          'thumbnail': data['thumbnail']?['source'],
        };
      }
    } catch (e) {
      print('Error fetching Wikipedia data: $e');
    }
    return null;
  }
}
