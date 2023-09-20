import 'dart:io';

import 'package:github/github.dart';
import 'package:pub_api_client/pub_api_client.dart';
import 'package:pubspec_lock_parse/pubspec_lock_parse.dart';

import 'model.dart';

class PubspecAnalyzer {
  final PubClient pubClient;
  final GitHub githubClient;

  PubspecAnalyzer({
    required this.pubClient,
    required this.githubClient,
  });

  Future<void> score(final PubspecLock lockfile, final bool onlyDirectDependencies, final Scoring scoring) async {
    final packagesInfo = await _fechPackagesInfo(lockfile, onlyDirectDependencies);
    final sortedPackageInfo = await _sort(packagesInfo);
    final htmlOutput = await _toHtml(sortedPackageInfo, scoring);
    await _writeIntoFile(htmlOutput);
  }

  Future<List<PackageInfo>> _fechPackagesInfo(final PubspecLock lockfile, final bool onlyDirectDependencies) async {
    print('Dependencies found in lockfile:');
    final allPackagesInfo = List<PackageInfo>.empty(growable: true);

    for (final packageInfo in lockfile.packages.entries) {
      final packageName = packageInfo.key;
      final package = packageInfo.value;

      if (![PackageSource.git, PackageSource.hosted].contains(package.source)) {
        print('$packageName: ${package.version} is ${package.source} => scoring skipped');
        continue;
      }

      if (onlyDirectDependencies && package.dependency == "transitive") {
        print('$packageName: ${package.version} is ${package.dependency} deps => scoring skipped');
        continue;
      }

      Repository? repoInfo;
      int? contributorsNumber;
      int? activeContributorsNumber;
      final String url;
      final PackageScore? packageScore;
      final String? latestVersion;
      final int? numberOfVersionsAhead;
      final int? numberOfMajorVersionsAhead;
      final String? repository;
      final String currentVersion;

      if (package.source == PackageSource.hosted) {
        currentVersion = package.version.toString();
        print("Scoring Package: $packageName");
        final packageInfo = await pubClient.packageInfo(packageName);
        packageScore = await pubClient.packageScore(packageName);
        latestVersion = packageInfo.latest.version;
        final releasedVersions = packageInfo.versions.where((element) => !element.version.contains("rc")).toList();
        final indexCurrentVersion = releasedVersions.indexWhere((element) => element.version == currentVersion);
        final indexLastVersion = releasedVersions.indexWhere((element) => element.version == latestVersion);
        numberOfVersionsAhead = indexLastVersion - indexCurrentVersion;
        url = packageInfo.url;
        final currentMajorVersion = currentVersion.split('.').first;
        final latestMajorVersion = packageInfo.latest.version.split('.').first;
        final allMajorVersions =
            packageInfo.versions.map((version) => version.version.split('.').first).toSet().toList();
        final indexCurrentMajorVersion = allMajorVersions.indexOf(currentMajorVersion);
        final indexLastMajorVersion = allMajorVersions.indexOf(latestMajorVersion);
        numberOfMajorVersionsAhead = indexLastMajorVersion - indexCurrentMajorVersion;

        final jsonPackageInfo = packageInfo.latest.pubspec.toJson();
        repository = jsonPackageInfo['repository'] ?? jsonPackageInfo['homepage'];
      } else {
        var description = package.description as GitPackageDescription;
        repository = description.url.replaceFirst('.git', '/tree/${description.ref}');
        url = repository;
        currentVersion = description.ref;
        latestVersion = null;
        numberOfVersionsAhead = null;
        numberOfMajorVersionsAhead = null;
        packageScore = null;
      }

      if (repository != null && repository.contains("https://github.com/")) {
        final fullName = repository.substring('https://github.com/'.length);
        final splittedFullName = fullName.split('/');
        final owner = splittedFullName[0];
        final projectName = splittedFullName[1];

        try {
          repoInfo = await githubClient.repositories.getRepository(RepositorySlug(owner, projectName));
          final contributors = githubClient.repositories.listContributors(RepositorySlug(owner, projectName));
          final commits = githubClient.repositories
              .listCommits(RepositorySlug(owner, projectName), since: DateTime.now().subtract(Duration(days: 2 * 30)));
          contributorsNumber = await contributors.length;
          activeContributorsNumber = (await commits.map((commit) => commit.author?.id).toSet()).length;
        } catch (exception) {
          repoInfo = null;
          contributorsNumber = null;
          activeContributorsNumber = null;
          print("Error while fetching repo info for $repository - $exception");
        }
      } else {
        repoInfo = null;
        contributorsNumber = null;
        activeContributorsNumber = null;
      }

      // return contributors who recently contributed to the project

      final packageInfoToScore = PackageInfo(
        packageName: packageName,
        url: url,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        likes: packageScore?.likeCount,
        popularity: packageScore?.popularityScore,
        pubPoints: packageScore?.grantedPoints,
        openIssuesCount: repoInfo?.openIssuesCount,
        starCount: repoInfo?.stargazersCount,
        daysSinceLastPush: repoInfo == null ? null : DateTime.now().difference(repoInfo.pushedAt!).inDays,
        isFork: repoInfo?.isFork,
        numberOfVersionsAhead: numberOfVersionsAhead,
        numberOfMajorVersionsAhead: numberOfMajorVersionsAhead,
        numberOfContributors: contributorsNumber,
        numberOfActiveContributors: activeContributorsNumber,
      );

      allPackagesInfo.add(packageInfoToScore);
    }

    return allPackagesInfo;
  }

  Future<List<PackageInfo>> _sort(List<PackageInfo> packagesInfo) async {
    packagesInfo.sort((packageInfo1, packageInfo2) {
      if ((packageInfo1.numberOfActiveContributors ?? -1) < (packageInfo2.numberOfActiveContributors ?? -1)) {
        return -1;
      }

      if ((packageInfo1.daysSinceLastPush ?? -1) < (packageInfo2.daysSinceLastPush ?? -1)) {
        return -1;
      }

      if ((packageInfo1.starCount ?? -1) < (packageInfo2.starCount ?? -1)) {
        return -1;
      }

      if ((packageInfo1.openIssuesCount ?? -1) < (packageInfo2.openIssuesCount ?? -1)) {
        return -1;
      }

      if ((packageInfo1.numberOfMajorVersionsAhead ?? 0) < (packageInfo2.numberOfMajorVersionsAhead ?? 0)) {
        return -1;
      }

      if ((packageInfo1.numberOfVersionsAhead ?? 0) < (packageInfo2.numberOfVersionsAhead ?? 0)) {
        return -1;
      }
      if ((packageInfo1.numberOfContributors ?? -1) < (packageInfo2.numberOfContributors ?? -1)) {
        return -1;
      }
      if ((packageInfo1.popularity ?? -1) < (packageInfo2.popularity ?? -1)) {
        return -1;
      }

      if ((packageInfo1.likes ?? 0) < (packageInfo2.likes ?? 0)) {
        return -1;
      }

      if ((packageInfo1.pubPoints ?? -1) <= (packageInfo2.pubPoints ?? -1)) {
        return -1;
      }
      if (packageInfo1.isFork ?? true) {
        return -1;
      }

      return 1;
    });

    return packagesInfo;
  }
}

Future<String> _toHtml(List<PackageInfo> packagesInfo, Scoring scoring) async {
  String html = '''
<!DOCTYPE html>
<html>
<style>
#packages {
  font-family: Arial, Helvetica, sans-serif;
  border-collapse: collapse;
  width: 100%;
}

#packages td, #packages th {
  border: 5px solid #ddd;
  padding: 8px;
  text-align: center;
  vertical-align: middle;
}

#packages tr:nth-child(even){background-color: #f2f2f2;}

#packages tr:hover {background-color: #dddd;}

#packages th {
  padding-top: 12px;
  padding-bottom: 12px;
  text-align: left;
  background-color: #3630a3;
  color: white;
}
.minimal { color:white; background-color:darkred }
.low { color:white; background-color:red }
.moderate { background-color:orange}
.high { background-color:lightGreen }

</style>
<body>

<h2>Pubspec scoring</h2>
''';

  String table = '<table id="packages">\n';

  table += '\t<thead>\n';
  table += '\t\t<tr>\n';
  table += '\t\t\t<th>Package Name</th>\n';
  table += '\t\t\t<th>Number of Contributors</th>\n';
  table += '\t\t\t<th>Number of Active contributors</th>\n';
  table += '\t\t\t<th>Current Version</th>\n';
  table += '\t\t\t<th>Latest version</th>\n';
  table += '\t\t\t<th>Number of Major version Ahead</th>\n';
  table += '\t\t\t<th>Number of version Ahead</th>\n';

  table += '\t\t\t<th>Days since Last push</th>\n';

  table += '\t\t\t<th>Number of open issues</th>\n';
  table += '\t\t\t<th>Number of Github Stars</th>\n';
  table += '\t\t\t<th>Likes</th>\n';
  table += '\t\t\t<th>Popularity</th>\n';
  table += '\t\t\t<th>Number of Pub points</th>\n';
  table += '\t\t\t<th>Is Forked</th>\n';

  table += '\t\t</tr>\n';
  table += '\t</thead>\n';

  table += '\t<tbody>\n';
  for (var element in packagesInfo) {
    table += '\t\t<tr>\n';
    table += '\t\t\t<td><a href="${element.url}"> ${element.packageName}</a></td>\n';
    table +=
        '\t\t\t<td class="${scoring.scoreNumberOfContributors(element.numberOfContributors)?.name ?? ''}">${element.numberOfContributors?.toString() ?? '?'}</td>\n';
    table +=
        '\t\t\t<td class="${scoring.scoreNumberOfActiveContributors(element.numberOfActiveContributors)?.name ?? ''}">${element.numberOfActiveContributors?.toString() ?? '?'}</td>\n';
    table += '\t\t\t<td>${element.currentVersion}</td>\n';
    table += '\t\t\t<td>${element.latestVersion?.toString() ?? '?'}</td>\n';
    table +=
        '\t\t\t<td class="${scoring.scoreNumberOfMajorVersionsAhead(element.numberOfMajorVersionsAhead)?.name ?? ''}">${element.numberOfMajorVersionsAhead?.toString() ?? '?'}</td>\n';

    table +=
        '\t\t\t<td class="${scoring.scoreNumberOfVersionsAhead(element.numberOfVersionsAhead)?.name ?? ''}">${element.numberOfVersionsAhead?.toString() ?? '?'}</td>\n';
    table +=
        '\t\t\t<td class="${scoring.scoreDaysSinceLastPush(element.daysSinceLastPush)?.name ?? ''}">${element.daysSinceLastPush?.toString() ?? ''}</td>\n';
    table +=
        '\t\t\t<td class="${scoring.scoreOpenIssuesCount(element.openIssuesCount)?.name ?? ''}">${element.openIssuesCount?.toString() ?? ''}</td>\n';
    table +=
        '\t\t\t<td class="${scoring.scoreStarCount(element.starCount)?.name ?? ''}">${element.starCount?.toString() ?? ''}</td>\n';
    table +=
        '\t\t\t<td class=${scoring.scoreLikes(element.likes)?.name ?? ''}>${element.likes?.toString() ?? ''}</td>\n';
    table +=
        '\t\t\t<td class="${scoring.scorePopularity(element.popularity)?.name ?? ''}">${((element.popularity ?? 0) * 100).toInt()}%</td>\n';
    table +=
        '\t\t\t<td class="${scoring.scorePubPoints(element.pubPoints)?.name ?? ''}">${element.pubPoints?.toString() ?? ''}</td>\n';
    table += '\t\t\t<td >${element.isFork?.toString() ?? ''}</td>\n';
    table += '\t\t</tr>\n';
  }
  table += '\t</tbody>\n';
  table += '</table>\n';
  html += table;
  html += '</body>';
  html += '</html>';
  return html;
}

Future<void> _writeIntoFile(String htmlOutput) async {
  final directory = Directory("output");
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  await File("output/scoring.html").writeAsString(htmlOutput);
}

enum Score { minimal, low, moderate, high }

abstract interface class Scoring {
  Score? scorePopularity(double? popularity);
  Score? scorePubPoints(int? pubPoints);
  Score? scoreOpenIssuesCount(int? openIssuesCount);
  Score? scoreStarCount(int? starCount);
  Score? scoreLikes(int? likes);
  Score? scoreDaysSinceLastPush(int? daysSinceLastPush);
  Score? scoreNumberOfMajorVersionsAhead(int? numberOfMajorVersions);
  Score? scoreNumberOfVersionsAhead(int? numberOfVersionsAhead);
  Score? scoreNumberOfContributors(int? numberOfContributor);
  Score? scoreNumberOfActiveContributors(int? numberOfContributor);
}

class DefaultScoring implements Scoring {
  @override
  Score? scorePopularity(double? popularity) {
    if (popularity == null) return null;
    if (popularity < 0.7) return Score.low;
    if (popularity < 0.9) return Score.moderate;
    return Score.high;
  }

  @override
  Score? scorePubPoints(int? pubPoints) {
    if (pubPoints == null) return null;
    if (pubPoints < 90) return Score.low;
    if (pubPoints < 120) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreOpenIssuesCount(int? openIssuesCount) {
    if (openIssuesCount == null) return null;
    if (openIssuesCount > 100) return Score.low;
    if (openIssuesCount > 30) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreStarCount(int? starCount) {
    if (starCount == null) return null;
    if (starCount < 10) return Score.low;
    if (starCount < 100) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreLikes(int? likes) {
    if (likes == null) return null;
    if (likes < 100) return Score.low;
    if (likes < 1000) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreDaysSinceLastPush(int? daysSinceLastPush) {
    if (daysSinceLastPush == null) return null;
    if (daysSinceLastPush > 2 * 365) return Score.minimal;
    if (daysSinceLastPush > 365) return Score.low;
    if (daysSinceLastPush > 90) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreNumberOfVersionsAhead(int? numberOfVersionsAhead) {
    if (numberOfVersionsAhead == null) return null;
    if (numberOfVersionsAhead > 20) return Score.minimal;
    if (numberOfVersionsAhead > 10) return Score.low;
    if (numberOfVersionsAhead > 2) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreNumberOfMajorVersionsAhead(int? numberOfMajorVersionsAhead) {
    if (numberOfMajorVersionsAhead == null) return null;
    if (numberOfMajorVersionsAhead > 2) return Score.minimal;
    if (numberOfMajorVersionsAhead > 1) return Score.low;
    if (numberOfMajorVersionsAhead > 0) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreNumberOfContributors(int? numberOfContributor) {
    if (numberOfContributor == null) return null;
    if (numberOfContributor < 2) return Score.low;
    if (numberOfContributor < 5) return Score.moderate;

    return Score.high;
  }

  @override
  Score? scoreNumberOfActiveContributors(int? numberOfContributor) {
    if (numberOfContributor == null) return null;
    if (numberOfContributor == 0) return Score.minimal;
    if (numberOfContributor < 2) return Score.low;
    if (numberOfContributor < 5) return Score.moderate;

    return Score.high;
  }
}
