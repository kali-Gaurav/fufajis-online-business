import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GitHubService {
  static final GitHubService _instance = GitHubService._internal();
  factory GitHubService() => _instance;
  GitHubService._internal();

  static const String _owner = 'fufajionline';
  static const String _repo = 'fufaji-online-app';

  /// Fetches the latest release version from GitHub API
  Future<String?> getLatestReleaseVersion() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String tagName = data['tag_name'] as String? ?? '';
        // Remove 'v' prefix if present (e.g., v1.2.3 -> 1.2.3)
        if (tagName.startsWith('v')) {
          tagName = tagName.substring(1);
        }
        return tagName;
      } else {
        debugPrint('GitHub API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching latest release: $e');
      return null;
    }
  }
}
