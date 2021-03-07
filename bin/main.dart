import 'dart:io';

import 'package:args/args.dart';
import 'package:github_metrics/github_metrics.dart';

Future<void> main(List<String> arguments) async {
  _args = _argParser.parse(arguments);
  if (!_args.wasParsed(_argRepo) || !_args.wasParsed(_argLabelPrefix)) {
    print('Run a web server hosting GitHub Issue metrics at /metrics.');
    print('');
    print(_argParser.usage);
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 4040);
  print('Listening on http://${server.address.address}:${server.port}/metrics');

  await for (final HttpRequest request in server) {
    try {
      switch (request.uri.path) {
        case '/metrics':
          final metrics = await _fetchMetrics();
          request.response.write(metrics);
          break;
        default:
          request.response.statusCode = 404;
          request.response.write('Not Found');
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      request.response.statusCode = 500;
      final message = '$e\n\n$s';
      final commentedMessage =
          message.split('\n').map((l) => '# $l').join('\n');
      request.response.write(commentedMessage);
    }
    await request.response.close();
  }
}

late ArgResults _args;
const _argRepo = 'repo';
const _argLabelPrefix = 'label-prefix';
const _argMaxIssuePages = 'max-issue-pages';

final _argParser = ArgParser()
  ..addOption(_argRepo,
      help:
          'The repository to fetch metrics for in the form user/repo or org/repo.')
  ..addMultiOption(
    _argLabelPrefix,
    help: 'Prefixes or labels to bucket issues into. These should generally be '
        'non-overlapping to avoid issues being counted multiple times',
  )
  ..addOption(
    _argMaxIssuePages,
    defaultsTo: '20',
    help: 'The maximum number of pages of open issues to fetch',
  );

Future<void> _appendCounts(StringBuffer buffer) async {
  final repo = _args[_argRepo];
  final labelPrefixes = _args[_argLabelPrefix];
  final maxPages = int.parse(_args[_argMaxIssuePages]);

  final counts = await getLabelCounts(
    repo: repo,
    labelPrefixes: labelPrefixes,
    maxPages: maxPages,
  );
  for (final prefix in counts.keys) {
    _writeMetric(buffer, 'github_issue_metrics_labels', counts[prefix]!,
        {'repo': repo, 'label': prefix});
  }
  final openClosed = await getOpenClosedIssues(repo: repo);
  _writeMetric(
      buffer, 'github_issue_metrics_open', openClosed.item1, {'repo': repo});
  _writeMetric(
      buffer, 'github_issue_metrics_closed', openClosed.item2, {'repo': repo});
}

Future<String> _fetchMetrics() async {
  final buffer = StringBuffer();
  await Future.wait([
    _appendCounts(buffer),
  ]);
  return buffer.toString();
}

String _metricName(String input) {
  final _idInvalidchars = RegExp(r'\W+');
  return input.replaceAll(_idInvalidchars, '_');
}

void _writeMetric(
  StringBuffer buffer,
  String name,
  int? value, [
  Map<String, String>? labels,
]) {
  name = _metricName(name);
  final labelString = labels != null
      ? '{${labels.keys.map((label) => "$label='${labels[label]}'").join(', ')}}'
      : '';
  return buffer.writeln('$name$labelString: $value');
}
