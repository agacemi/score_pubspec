import 'dart:io';

import 'package:args/args.dart';
import 'package:github/github.dart';
import 'package:pub_api_client/pub_api_client.dart';
import 'package:pubspec_lock_parse/pubspec_lock_parse.dart';
import 'package:score_pubspec/score_pubspec.dart';

void main(List<String> arguments) async {
  final argParser = ArgParser();
  argParser.addOption('path', abbr: 'p');
  argParser.addFlag('only-direct-deps', abbr: 'd');
  final result = argParser.parse(arguments);
  final onlyDirectDependencies = result['only-direct-deps'] ?? false;

  final pubClient = PubClient();
  final githubToken = Platform.environment['GITHUB_TOKEN'];
  if (githubToken?.isEmpty ?? true) {
    throw Exception('GITHUB_TOKEN is not set');
  }
  final githubClient = GitHub(auth: Authentication.withToken(githubToken));
  final pubspecScorer = PubspecAnalyzer(pubClient: pubClient, githubClient: githubClient);

  final pubspecLockPath = File((result['path']) ?? 'pubspec.lock').readAsStringSync();
  final pubspecLock = PubspecLock.parse(pubspecLockPath);

  await pubspecScorer.score(pubspecLock, onlyDirectDependencies, DefaultScoring());
}
