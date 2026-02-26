import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_service.dart';
import '../core/models/help_request.dart';
import '../core/models/rescue_team.dart';
import '../core/models/teams_snapshot.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  TeamsSnapshot? snapshot;
  bool loading = true;
  bool savingTeam = false;
  String? busyRequestId;
  Timer? _pollTimer;

  final Map<String, String> _selectedTeamByRequest = {};

  final TextEditingController _teamIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _membersController = TextEditingController(
    text: '4',
  );
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String _teamStatus = 'AVAILABLE';

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _teamIdController.dispose();
    _nameController.dispose();
    _membersController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => loading = true);
    }
    try {
      final data = await ApiService.fetchTeamsSnapshot();
      if (!mounted) return;
      setState(() {
        snapshot = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _assign(HelpRequest request) async {
    final teams = snapshot?.teams ?? const [];
    final selectedTeamId =
        _selectedTeamByRequest[request.requestId] ??
        _firstOrNull(
          teams.where((t) => t.status == 'AVAILABLE').map((t) => t.teamId),
        );
    if (selectedTeamId == null || selectedTeamId.isEmpty) {
      _snack('No available team to assign');
      return;
    }

    setState(() => busyRequestId = request.requestId);
    try {
      await ApiService.assignTeamToHelpRequest(
        requestId: request.requestId,
        teamId: selectedTeamId,
      );
      if (!mounted) return;
      _snack('Assigned $selectedTeamId to request ${request.requestId}');
      await _load(silent: true);
    } catch (_) {
      if (!mounted) return;
      _snack('Failed to assign team');
    } finally {
      if (mounted) {
        setState(() => busyRequestId = null);
      }
    }
  }

  Future<void> _notifyNearby(HelpRequest request) async {
    setState(() => busyRequestId = request.requestId);
    try {
      final notified = await ApiService.notifyNearbyTeams(
        requestId: request.requestId,
        radiusKm: 5,
      );
      if (!mounted) return;
      _snack('Notified $notified nearby teams');
      await _load(silent: true);
    } catch (_) {
      if (!mounted) return;
      _snack('Unable to notify nearby teams for this request');
    } finally {
      if (mounted) {
        setState(() => busyRequestId = null);
      }
    }
  }

  Future<void> _saveTeam() async {
    final teamId = _teamIdController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final members = int.tryParse(_membersController.text.trim());
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (teamId.isEmpty || name.isEmpty || members == null || lat == null || lng == null) {
      _snack('Fill valid team ID, name, members, lat and lng');
      return;
    }

    setState(() => savingTeam = true);
    try {
      await ApiService.upsertRescueTeam(
        teamId: teamId,
        name: name,
        membersCount: members,
        status: _teamStatus,
        lat: lat,
        lng: lng,
        contactNumber: _contactController.text.trim(),
      );
      if (!mounted) return;
      _snack('Team saved');
      _teamIdController.clear();
      _nameController.clear();
      _membersController.text = '4';
      _latController.clear();
      _lngController.clear();
      _contactController.clear();
      setState(() => _teamStatus = 'AVAILABLE');
      await _load(silent: true);
    } catch (_) {
      if (!mounted) return;
      _snack('Failed to save team');
    } finally {
      if (mounted) {
        setState(() => savingTeam = false);
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data =
        snapshot ??
        TeamsSnapshot(
          teams: const [],
          helpRequests: const [],
          stats: TeamStats(
            totalTeams: 0,
            availableTeams: 0,
            deployedTeams: 0,
            offlineTeams: 0,
            totalMembers: 0,
            openHelpRequests: 0,
            assignedHelpRequests: 0,
            notificationsSent: 0,
          ),
        );

    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final compact = MediaQuery.sizeOf(context).width < 1020 || isAndroidUi;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(compact ? 12 : 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rescue Teams',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Assign teams to citizen help requests, track locations, and notify nearby units.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip('Teams', data.stats.totalTeams),
              _statChip('Available', data.stats.availableTeams),
              _statChip('Deployed', data.stats.deployedTeams),
              _statChip('Offline', data.stats.offlineTeams),
              _statChip('Responders', data.stats.totalMembers),
              _statChip('Open Requests', data.stats.openHelpRequests),
              _statChip('Assigned Requests', data.stats.assignedHelpRequests),
              _statChip('Notifications', data.stats.notificationsSent),
            ],
          ),
          const SizedBox(height: 12),
          _mapCard(data),
          const SizedBox(height: 12),
          if (compact) ...[
            _requestCard(data),
            const SizedBox(height: 12),
            _teamFormCard(),
            const SizedBox(height: 12),
            _teamsListCard(data),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _requestCard(data)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _teamFormCard(),
                      const SizedBox(height: 12),
                      _teamsListCard(data),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _mapCard(TeamsSnapshot data) {
    const fallbackCenter = LatLng(19.0760, 72.8777);
    LatLng center = fallbackCenter;
    if (data.helpRequests.isNotEmpty) {
      final req = data.helpRequests.firstWhere(
        (r) => r.lat != null && r.lng != null,
        orElse: () => data.helpRequests.first,
      );
      if (req.lat != null && req.lng != null) {
        center = LatLng(req.lat!, req.lng!);
      }
    } else if (data.teams.isNotEmpty) {
      final team = data.teams.firstWhere(
        (t) => t.lat != null && t.lng != null,
        orElse: () => data.teams.first,
      );
      if (team.lat != null && team.lng != null) {
        center = LatLng(team.lat!, team.lng!);
      }
    }

    return Card(
      child: SizedBox(
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 11.5),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              MarkerLayer(
                markers: [
                  ...data.teams
                      .where((t) => t.lat != null && t.lng != null)
                      .map(
                        (team) => Marker(
                          point: LatLng(team.lat!, team.lng!),
                          width: 36,
                          height: 36,
                          child: Tooltip(
                            message: '${team.teamId} • ${team.status}',
                            child: Icon(
                              Icons.groups_rounded,
                              color: team.status == 'AVAILABLE'
                                  ? const Color(0xFF2F855A)
                                  : team.status == 'DEPLOYED'
                                  ? const Color(0xFFDD6B20)
                                  : const Color(0xFF4A5568),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                  ...data.helpRequests
                      .where((r) => r.lat != null && r.lng != null)
                      .map(
                        (request) => Marker(
                          point: LatLng(request.lat!, request.lng!),
                          width: 34,
                          height: 34,
                          child: Tooltip(
                            message:
                                'Help ${request.requestId} • ${request.category}',
                            child: const Icon(
                              Icons.sos_rounded,
                              color: Color(0xFFC53030),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestCard(TeamsSnapshot data) {
    final openFirst = [...data.helpRequests]
      ..sort((a, b) {
        if (a.status == b.status) return 0;
        return a.status == 'OPEN' ? -1 : 1;
      });
    final availableTeams = data.teams.where((t) => t.status == 'AVAILABLE').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incoming Help Requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (openFirst.isEmpty)
              Text(
                'No open or assigned help requests right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...openFirst.map((r) {
                final isBusy = busyRequestId == r.requestId;
                final currentSelection =
                    _selectedTeamByRequest[r.requestId] ??
                    r.assignedTeamId ??
                    _firstOrNull(availableTeams.map((t) => t.teamId));
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('ID: ${r.requestId}')),
                          Chip(label: Text('Status: ${r.status}')),
                          Chip(label: Text('Category: ${r.category}')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Contact: ${r.contactNumber}'),
                      if (r.lat != null && r.lng != null)
                        Text(
                          'Location: ${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}',
                        ),
                      if (r.createdAt != null)
                        Text('Opened: ${r.createdAt}'),
                      const SizedBox(height: 10),
                      if (r.status == 'OPEN') ...[
                        DropdownButtonFormField<String>(
                          initialValue: currentSelection,
                          items: availableTeams
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.teamId,
                                  child: Text('${t.teamId} • ${t.name}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedTeamByRequest[r.requestId] = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Assign Team',
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: isBusy || r.status != 'OPEN'
                                ? null
                                : () => _assign(r),
                            icon: isBusy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.assignment_ind_rounded),
                            label: const Text('Assign Team'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: isBusy || r.lat == null || r.lng == null
                                ? null
                                : () => _notifyNearby(r),
                            icon: const Icon(Icons.notifications_active_rounded),
                            label: const Text('Notify Nearby Teams'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _teamFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add / Update Team',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _teamIdController,
              decoration: const InputDecoration(labelText: 'Team ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Team Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _membersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Members'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Team Contact (Optional)',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _teamStatus,
              items: const [
                DropdownMenuItem(value: 'AVAILABLE', child: Text('AVAILABLE')),
                DropdownMenuItem(value: 'DEPLOYED', child: Text('DEPLOYED')),
                DropdownMenuItem(value: 'OFFLINE', child: Text('OFFLINE')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _teamStatus = v);
              },
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: savingTeam ? null : _saveTeam,
              icon: savingTeam
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save Team'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamsListCard(TeamsSnapshot data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teams',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (data.teams.isEmpty)
              Text(
                'No teams available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...data.teams.map(_teamTile),
          ],
        ),
      ),
    );
  }

  Widget _teamTile(RescueTeam team) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(team.teamId)),
              Chip(label: Text(team.status)),
              Chip(label: Text('Members: ${team.membersCount}')),
            ],
          ),
          const SizedBox(height: 4),
          Text(team.name),
          if (team.lat != null && team.lng != null)
            Text(
              'Location: ${team.lat!.toStringAsFixed(5)}, ${team.lng!.toStringAsFixed(5)}',
            ),
          if ((team.contactNumber ?? '').isNotEmpty)
            Text('Contact: ${team.contactNumber}'),
          if ((team.assignedRequestId ?? '').isNotEmpty)
            Text('Assigned Request: ${team.assignedRequestId}'),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value) {
    return Chip(label: Text('$label: $value'));
  }
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}
