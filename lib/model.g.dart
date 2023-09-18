// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageInfo _$PackageInfoFromJson(Map<String, dynamic> json) => PackageInfo(
      packageName: json['packageName'] as String,
      url: json['url'] as String,
      currentVersion: json['currentVersion'] as String,
      latestVersion: json['latestVersion'] as String,
      openIssuesCount: json['openIssuesCount'] as int?,
      likes: json['likes'] as int,
      pubPoints: json['pubPoints'] as int?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      starCount: json['starCount'] as int?,
      daysSinceLastPush: json['daysSinceLastPush'] as int?,
      isFork: json['isFork'] as bool?,
      numberOfVersionsAhead: json['numberOfVersionsAhead'] as int,
      numberOfMajorVersionsAhead: json['numberOfMajorVersionsAhead'] as int,
      numberOfContributors: json['numberOfContributors'] as int?,
      numberOfActiveContributors: json['numberOfActiveContributors'] as int?,
    );

Map<String, dynamic> _$PackageInfoToJson(PackageInfo instance) =>
    <String, dynamic>{
      'packageName': instance.packageName,
      'url': instance.url,
      'currentVersion': instance.currentVersion,
      'latestVersion': instance.latestVersion,
      'likes': instance.likes,
      'pubPoints': instance.pubPoints,
      'popularity': instance.popularity,
      'openIssuesCount': instance.openIssuesCount,
      'starCount': instance.starCount,
      'isFork': instance.isFork,
      'daysSinceLastPush': instance.daysSinceLastPush,
      'numberOfVersionsAhead': instance.numberOfVersionsAhead,
      'numberOfMajorVersionsAhead': instance.numberOfMajorVersionsAhead,
      'numberOfContributors': instance.numberOfContributors,
      'numberOfActiveContributors': instance.numberOfActiveContributors,
    };
