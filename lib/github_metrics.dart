import 'dart:convert';
import 'package:tuple/tuple.dart';

import 'package:http/http.dart' as http;

Future<Map<String, int>> getLabelCounts(
    {required String repo,
    required List<String> labelPrefixes,
    required int maxPages}) async {
  var page = 0;
  final counts = <String, int>{
    for (final prefix in labelPrefixes) prefix: 0,
  };
  while (++page <= maxPages) {
    final json = await _fetch(Uri.parse(
        'https://api.github.com/repos/$repo/issues?per_page=100&page=$page'));
    final issues = jsonDecode(json) as List;
    if (issues.isEmpty) {
      print('No more results!');
      break;
    }
    for (final issue in issues) {
      if (issue['pull_request'] != null) {
        continue;
      }
      counts['other'] = (counts['other'] ?? 0) + 1;
      for (final label in (issue['labels'] ?? []) as List) {
        final prefix = labelPrefixes.cast<String?>().singleWhere(
            (l) => (label['name'] as String).startsWith(l!),
            orElse: () => null);
        if (prefix != null) {
          counts[prefix] = (counts[prefix] ?? 0) + 1;
          counts['other'] = (counts['other'] ?? 0) - 1;
          break;
        }
      }
    }
  }

  return counts;
}

Future<String> _fetch(Uri uri) async {
  print('Fetching $uri');
  final resp = await http.get(uri);

  final ratelimitReset =
      int.tryParse(resp.headers['x-ratelimit-reset'] ?? ''); // 1615144912
  final ratelimitLimit =
      int.tryParse(resp.headers['x-ratelimit-limit'] ?? ''); // 60
  final ratelimitRemaining =
      int.tryParse(resp.headers['x-ratelimit-remaining'] ?? ''); // 53

  if (ratelimitRemaining != null &&
      ratelimitLimit != null &&
      ratelimitReset != null &&
      ratelimitRemaining < 1) {
    final resetTime =
        DateTime.fromMillisecondsSinceEpoch(ratelimitReset * 1000);
    throw Exception(
        'GitHub rate limit ($ratelimitLimit per hour) exhausted. Resets at $resetTime');
  }

  return resp.body;
}

Future<Tuple2<int, int>> getOpenClosedIssues({required String repo}) async {
  // Scrape totals from the page, since closed issues aren't
  // included in the API.
  final openIssueCountPattern = RegExp(r'\s+([\d,]+) Open\s+');
  final closedIssueCountPattern = RegExp(r'\s+([\d,]+) Closed\s+');
  final html = await _fetch(Uri.parse('https://github.com/$repo/issues'));
  final openIssues = int.parse(
      openIssueCountPattern.firstMatch(html)!.group(1)!.replaceAll(',', ''));
  final closedIssues = int.parse(
      closedIssueCountPattern.firstMatch(html)!.group(1)!.replaceAll(',', ''));
  return Tuple2<int, int>(openIssues, closedIssues);
}
