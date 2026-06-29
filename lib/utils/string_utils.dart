import 'dart:math';

class StringUtils {
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < s2.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  static bool isPhoneticMatch(String query, String target, {int threshold = 2}) {
    if (target.contains(query)) return true;
    if (levenshteinDistance(query, target) <= threshold) return true;
    return false;
  }
}
