import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable()
class PackageInfo {
  final String packageName;
  final String url;
  final String currentVersion;
  final String? latestVersion;
  final int? likes;
  final int? pubPoints;
  final double? popularity;
  final int? openIssuesCount;
  final int? starCount;
  final bool? isFork;
  final int? daysSinceLastPush;
  final int? numberOfVersionsAhead;
  final int? numberOfMajorVersionsAhead;
  final int? numberOfContributors;
  final int? numberOfActiveContributors;

  PackageInfo({
    required this.packageName,
    required this.url,
    required this.currentVersion,
    required this.latestVersion,
    required this.openIssuesCount,
    required this.likes,
    required this.pubPoints,
    required this.popularity,
    required this.starCount,
    required this.daysSinceLastPush,
    required this.isFork,
    required this.numberOfVersionsAhead,
    required this.numberOfMajorVersionsAhead,
    required this.numberOfContributors,
    required this.numberOfActiveContributors,
  });

  factory PackageInfo.fromJson(Map<String, dynamic> json) => _$PackageInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PackageInfoToJson(this);
}
