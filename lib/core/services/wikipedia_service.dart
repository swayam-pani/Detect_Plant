import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final wikipediaServiceProvider = Provider((ref) => WikipediaService());

/// Enum to specify what kind of information to fetch.
enum InfoFetchMode { plant, disease }

class WikipediaService {
  final Map<String, String> _headers = {
    'User-Agent':
        'DetectPlant/1.0 (https://github.com/Vishwaraj-636/DetectPlant; contact@example.com)',
  };

  /// Clean up model labels for API lookup:
  /// - Strip parenthetical text, e.g. "African Violet (Saintpaulia ionantha)" -> "African Violet"
  /// - Replace underscores with spaces, e.g. "Money_Plant" -> "Money Plant"
  String _cleanLabel(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ').trim();
    cleaned = cleaned.replaceAll('_', ' ').trim();
    return cleaned;
  }

  /// Extracts scientific name if present in parentheses for high-precision search
  String _extractScientificName(String raw) {
    final match = RegExp(r'\((.*?)\)').firstMatch(raw);
    if (match != null) {
      return match.group(1)?.trim() ?? _cleanLabel(raw);
    }
    return _cleanLabel(raw);
  }

  /// Main method to fetch information.
  ///
  /// [labelName] — The detected label from the model (plant name or disease class).
  /// [mode] — Whether user is in plant detection or disease detection mode.
  ///
  /// In **plant mode**, fetches general info about the plant.
  /// In **disease mode**, fetches info about common diseases of that plant.
  Future<Map<String, dynamic>?> fetchInfo(
    String labelName,
    InfoFetchMode mode,
  ) async {
    print('Starting Info Lookup for: "$labelName" (mode: ${mode.name})');

    if (mode == InfoFetchMode.plant) {
      return _fetchPlantInfo(labelName);
    } else {
      return _fetchDiseaseInfo(labelName);
    }
  }

  /// Backward-compatible alias (still used elsewhere if needed)
  Future<Map<String, dynamic>?> getDiseaseInfo(String labelName) async {
    return fetchInfo(labelName, InfoFetchMode.plant);
  }

  // ────────────────────────────────────────────────
  // PLANT MODE — fetch general info about the plant
  // ────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchPlantInfo(String labelName) async {
    // 1. Try Wikipedia
    var result = await _fetchFromWikipediaAction(labelName, suffix: '');
    if (_hasGoodExtract(result)) {
      print('Plant info found on Wikipedia.');
      return result;
    }

    // 2. Fallback: DuckDuckGo
    print('Wikipedia plant info insufficient. Trying DuckDuckGo fallback...');
    result = await _fetchFromDuckDuckGo(labelName, suffix: ' plant');
    if (result != null) {
      print('Plant info found on DuckDuckGo.');
      return result;
    }

    return null;
  }

  // ──────────────────────────────────────────────────
  // DISEASE MODE — fetch disease-related info
  // ──────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchDiseaseInfo(String labelName) async {
    final cleaned = _cleanLabel(labelName);

    // Build a list of targeted search queries for plant diseases
    final searchQueries = [
      '$cleaned plant disease',
      '$cleaned leaf disease',
      '$cleaned common diseases',
      '$cleaned crop disease',
    ];

    // 1. Try Wikipedia with disease-specific queries
    for (final query in searchQueries) {
      var result = await _fetchFromWikipediaAction(
        query,
        suffix: '',
        requireDiseaseContent: true,
      );
      if (_hasGoodExtract(result)) {
        print('Disease info found on Wikipedia for query: "$query"');
        // Prefix the extract with context about the plant
        result!['extract'] =
            'Common diseases of $cleaned:\n\n${result['extract']}';
        return result;
      }
    }

    // 2. Try dedicated Wikipedia pages for well-known crop diseases
    final diseasePageTitles = [
      'List of ${cleaned.toLowerCase()} diseases',
      '${cleaned} diseases',
    ];
    for (final pageTitle in diseasePageTitles) {
      var result = await _fetchFromWikipediaAction(pageTitle, suffix: '');
      if (_hasGoodExtract(result)) {
        print('Disease list found on Wikipedia: "$pageTitle"');
        result!['extract'] =
            'Known diseases of $cleaned:\n\n${result['extract']}';
        return result;
      }
    }

    // 3. Fallback: DuckDuckGo with disease context
    print('Wikipedia disease info not found. Trying DuckDuckGo fallback...');
    var result = await _fetchFromDuckDuckGo(
      cleaned,
      suffix: ' plant diseases symptoms treatment',
    );
    if (result != null) {
      print('Disease info found on DuckDuckGo.');
      result['extract'] =
          'Disease information for $cleaned:\n\n${result['extract']}';
      return result;
    }

    // 4. Last resort: return general plant info with a note
    print(
      'No disease-specific info found. Falling back to general plant info...',
    );
    result = await _fetchFromWikipediaAction(cleaned, suffix: '');
    if (_hasGoodExtract(result)) {
      result!['extract'] =
          '⚠ No specific disease information was found. General info about $cleaned:\n\n${result['extract']}';
      return result;
    }

    return null;
  }

  // ────────────────────────────────────────────────
  // Wikipedia Action API
  // ────────────────────────────────────────────────

  bool _hasGoodExtract(Map<String, dynamic>? result) {
    return result != null &&
        result['extract'] != null &&
        result['extract'].toString().length > 100;
  }

  /// Uses a Search-first approach to find the correct Wikipedia page.
  /// [suffix] can be appended to steer search (e.g. " plant disease").
  /// [requireDiseaseContent] — if true, only accept results mentioning disease terms.
  Future<Map<String, dynamic>?> _fetchFromWikipediaAction(
    String query, {
    String suffix = '',
    bool requireDiseaseContent = false,
  }) async {
    try {
      final searchQuery = '$query$suffix'.trim();
      final scientificName = _extractScientificName(searchQuery);
      final commonName = _cleanLabel(searchQuery);

      // Search for the best matching page title.
      String? bestTitle = await _searchWikipediaTitle(scientificName);
      if (bestTitle == null && scientificName != commonName) {
        bestTitle = await _searchWikipediaTitle(commonName);
      }
      // Also try the raw query if nothing matched
      if (bestTitle == null && searchQuery != commonName) {
        bestTitle = await _searchWikipediaTitle(searchQuery);
      }

      if (bestTitle == null) return null;

      final url = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&prop=extracts|pageimages&exintro=1&explaintext=1&titles=${Uri.encodeComponent(bestTitle)}&pithumbsize=600&format=json&redirects=1',
      );

      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages == null || pages.isEmpty || pages.containsKey('-1'))
          return null;

        final page = pages.values.first;
        if (page['extract'] == null || page['extract'].toString().isEmpty)
          return null;

        final extract = page['extract'].toString();

        // If we require disease-related content, verify it is present
        if (requireDiseaseContent) {
          final lowerExtract = extract.toLowerCase();
          final diseaseTerms = [
            'disease',
            'pathogen',
            'fungal',
            'bacterial',
            'virus',
            'blight',
            'infection',
            'rot',
            'wilt',
            'mildew',
            'rust',
            'spot',
            'canker',
            'mosaic',
            'leaf curl',
            'necrosis',
            'anthracnose',
          ];
          final hasDiseaseContent = diseaseTerms.any(
            (term) => lowerExtract.contains(term),
          );
          if (!hasDiseaseContent) return null;
        }

        return {
          'title': page['title'],
          'extract': extract,
          'thumbnail': page['thumbnail']?['source'],
          'source': 'Wikipedia',
        };
      }
    } catch (e) {
      print('Wikipedia lookup failed: $e');
    }
    return null;
  }

  /// Internal search to find the correct page title on Wikipedia
  Future<String?> _searchWikipediaTitle(String query) async {
    try {
      final searchUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&srlimit=3&format=json',
      );
      final response = await http.get(searchUrl, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['query']?['search'] as List?;
        if (results != null && results.isNotEmpty) {
          // Return the first non-disambiguation result
          for (final result in results) {
            final title = result['title'] as String;
            if (!title.toLowerCase().contains('disambiguation')) {
              return title;
            }
          }
        }
      }
    } catch (e) {
      print('Wikipedia search error for "$query": $e');
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // DuckDuckGo Instant Answer API (fallback)
  // ────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchFromDuckDuckGo(
    String query, {
    String suffix = '',
  }) async {
    try {
      final cleaned = _cleanLabel('$query$suffix');
      final url = Uri.parse(
        'https://api.duckduckgo.com/?q=${Uri.encodeComponent(cleaned)}&format=json&t=DetectPlantApp',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final extract = data['AbstractText'] as String?;

        if (extract != null && extract.isNotEmpty) {
          String? imageUrl = data['Image'] as String?;
          if (imageUrl != null && imageUrl.startsWith('/')) {
            imageUrl = 'https://duckduckgo.com$imageUrl';
          }

          return {
            'title': data['Heading'] ?? cleaned,
            'extract': extract,
            'thumbnail': (imageUrl != null && imageUrl.isNotEmpty)
                ? imageUrl
                : null,
            'source': 'DuckDuckGo',
          };
        }
      }
    } catch (e) {
      print('DuckDuckGo fallback failed: $e');
    }
    return null;
  }
}
