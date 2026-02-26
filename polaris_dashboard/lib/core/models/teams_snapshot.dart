import 'help_request.dart';
import 'rescue_team.dart';

class TeamStats {
  final int totalTeams;
  final int availableTeams;
  final int deployedTeams;
  final int offlineTeams;
  final int totalMembers;
  final int openHelpRequests;
  final int assignedHelpRequests;
  final int notificationsSent;

  TeamStats({
    required this.totalTeams,
    required this.availableTeams,
    required this.deployedTeams,
    required this.offlineTeams,
    required this.totalMembers,
    required this.openHelpRequests,
    required this.assignedHelpRequests,
    required this.notificationsSent,
  });

  factory TeamStats.fromJson(Map<String, dynamic> json) {
    return TeamStats(
      totalTeams: (json['total_teams'] as num?)?.toInt() ?? 0,
      availableTeams: (json['available_teams'] as num?)?.toInt() ?? 0,
      deployedTeams: (json['deployed_teams'] as num?)?.toInt() ?? 0,
      offlineTeams: (json['offline_teams'] as num?)?.toInt() ?? 0,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      openHelpRequests: (json['open_help_requests'] as num?)?.toInt() ?? 0,
      assignedHelpRequests: (json['assigned_help_requests'] as num?)?.toInt() ?? 0,
      notificationsSent: (json['notifications_sent'] as num?)?.toInt() ?? 0,
    );
  }
}

class TeamsSnapshot {
  final List<RescueTeam> teams;
  final List<HelpRequest> helpRequests;
  final TeamStats stats;

  TeamsSnapshot({
    required this.teams,
    required this.helpRequests,
    required this.stats,
  });

  factory TeamsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTeams = (json['teams'] as List?) ?? const [];
    final rawRequests = (json['help_requests'] as List?) ?? const [];
    return TeamsSnapshot(
      teams: rawTeams
          .whereType<Map>()
          .map((e) => RescueTeam.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      helpRequests: rawRequests
          .whereType<Map>()
          .map((e) => HelpRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      stats: TeamStats.fromJson(
        Map<String, dynamic>.from(json['stats'] as Map? ?? const {}),
      ),
    );
  }
}
