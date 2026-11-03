import '../../profile/presentation/support_links.dart';

/// A feedback report that names the guide and its version.
///
/// The query carries those two facts only. Account, garden, and location
/// values are not added here.
Uri guideFeedbackUri({required String guideId, required int version}) {
  final issues = Uri.parse(SupportLinks.githubIssues);
  return issues.replace(
    path: '${issues.path}/new',
    queryParameters: {
      'title': 'Guide feedback: $guideId v$version',
      'body': 'guide_id: $guideId\nversion: $version',
    },
  );
}
