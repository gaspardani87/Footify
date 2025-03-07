import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MatchDetails extends StatefulWidget {
  final String matchId;

  const MatchDetails({super.key, required this.matchId});

  @override
  State<MatchDetails> createState() => _MatchDetailsState();
}

class _MatchDetailsState extends State<MatchDetails> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _matchDetailsFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _matchDetailsFuture = fetchMatchDetails(widget.matchId);
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<Map<String, dynamic>> fetchMatchDetails(String matchId) async {
    final proxyUrl = 'https://thingproxy.freeboard.io/fetch/';
    final apiUrl = 'https://api.football-data.org/v4/matches/$matchId';

    final response = await http.get(
      Uri.parse('$proxyUrl$apiUrl'),
      headers: {
        'X-Auth-Token': '4c553fac5d704101906782d1ecbe1b12',
        'x-cors-api-key': 'temp_b7020b5f16680aae2a61be69685f4115',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load match details: ${response.statusCode} ${response.body}');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.black,
        elevation: 2,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Lexend',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _matchDetailsFuture = fetchMatchDetails(widget.matchId);
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          labelStyle: const TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Lineups'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _matchDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          } else if (snapshot.hasError) {
            return _buildErrorWidget(colorScheme, snapshot.error.toString());
          } else if (snapshot.hasData) {
            final matchData = snapshot.data!;
            return TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(matchData),
                _buildLineups(matchData),
                _buildEvents(matchData),
              ],
            );
          } else {
            return Center(
              child: Text(
                'Match details not found',
                style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Lexend'),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Match Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'Lexend',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: $error\nPlease try again.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontFamily: 'Lexend',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _matchDetailsFuture = fetchMatchDetails(widget.matchId);
                });
              },
              child: const Text('Retry', style: TextStyle(fontFamily: 'Lexend')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> matchData) {
    final colorScheme = Theme.of(context).colorScheme;
    final competitionName = matchData['competition']?['name'] ?? 'Unknown Competition';
    final matchday = matchData['matchday']?.toString() ?? 'N/A';
    final stage = matchData['stage'] ?? 'N/A';
    final venue = matchData['venue'] ?? 'TBD';
    final attendance = matchData['attendance']?.toString() ?? 'N/A';
    final matchDate = DateTime.parse(matchData['utcDate']).add(const Duration(hours: 1));
    final formattedDateTime = '${matchDate.day}/${matchDate.month}/${matchDate.year} - '
        '${matchDate.hour.toString().padLeft(2, '0')}:${matchDate.minute.toString().padLeft(2, '0')}';
    final homeTeam = matchData['homeTeam'];
    final awayTeam = matchData['awayTeam'];
    final score = matchData['score']?['fullTime'];
    final halfTimeScore = matchData['score']?['halfTime'];
    final status = matchData['status'] ?? 'UNKNOWN';
    final minute = matchData['minute']?.toString() ?? '';
    final injuryTime = matchData['injuryTime']?.toString() ?? '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                Text(
                  competitionName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Lexend',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Matchday $matchday - $stage',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withOpacity(0.8),
                    fontFamily: 'Lexend',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedDateTime,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withOpacity(0.8),
                    fontFamily: 'Lexend',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      'Venue: $venue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.7),
                        fontFamily: 'Lexend',
                      ),
                    ),
                  ],
                ),
                Text(
                  'Attendance: $attendance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.7),
                    fontFamily: 'Lexend',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Team Section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTeamColumn(homeTeam, colorScheme, isHome: true),
                      Column(
                        children: [
                          Text(
                            score != null ? '${score['home']} - ${score['away']}' : 'vs',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Lexend',
                            ),
                          ),
                          if (halfTimeScore != null)
                            Text(
                              'HT: ${halfTimeScore['home']} - ${halfTimeScore['away']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withOpacity(0.7),
                                fontFamily: 'Lexend',
                              ),
                            ),
                        ],
                      ),
                      _buildTeamColumn(awayTeam, colorScheme, isHome: false),
                    ],
                  ),
                  if (status == 'IN_PLAY' && minute.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Chip(
                      label: Text(
                        '$minute\' + $injuryTime\'',
                        style: const TextStyle(color: Colors.red, fontFamily: 'Lexend'),
                      ),
                      backgroundColor: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status
          _buildStatusChip(status, colorScheme),

          const SizedBox(height: 16),

          // Goals
          if (matchData['goals'] != null && matchData['goals'].isNotEmpty)
            _buildGoalsSection(matchData['goals'], colorScheme),
        ],
      ),
    );
  }

  Widget _buildTeamColumn(Map<String, dynamic> team, ColorScheme colorScheme, {required bool isHome}) {
    return Column(
      children: [
        if (team['crest'] != null)
          Image.network(
            team['crest'],
            width: 60,
            height: 60,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.sports_soccer,
              size: 60,
              color: colorScheme.onSurface,
            ),
          )
        else
          Icon(Icons.sports_soccer, size: 60, color: colorScheme.onSurface),
        const SizedBox(height: 8),
        Text(
          team['name'] ?? 'Unknown Team',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            fontFamily: 'Lexend',
          ),
          textAlign: TextAlign.center,
        ),
        if (team['coach']?['name'] != null)
          Text(
            'Coach: ${team['coach']['name']}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.7),
              fontFamily: 'Lexend',
            ),
          ),
        if (team['leagueRank'] != null)
          Text(
            'Rank: ${team['leagueRank']}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.7),
              fontFamily: 'Lexend',
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(String status, ColorScheme colorScheme) {
    String statusText;
    Color statusColor;

    switch (status) {
      case 'IN_PLAY':
        statusText = 'Live';
        statusColor = Colors.red;
        break;
      case 'PAUSED':
        statusText = 'Half Time';
        statusColor = Colors.orange;
        break;
      case 'FINISHED':
        statusText = 'Finished';
        statusColor = Colors.green;
        break;
      case 'TIMED':
      case 'SCHEDULED':
        statusText = 'Upcoming';
        statusColor = colorScheme.primary;
        break;
      default:
        statusText = status;
        statusColor = Colors.grey;
    }

    return Center(
      child: Chip(
        label: Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lexend',
          ),
        ),
        backgroundColor: statusColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: statusColor),
        ),
      ),
    );
  }

  Widget _buildGoalsSection(List<dynamic> goals, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Lexend'),
            ),
            const SizedBox(height: 8),
            ...goals.map((goal) => ListTile(
                  leading: const Icon(Icons.sports_soccer, color: Colors.green),
                  title: Text(
                    '${goal['minute']}\' ${goal['scorer']?['name'] ?? 'Unknown'}',
                    style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Lexend'),
                  ),
                  subtitle: Text(
                    goal['assist']?['name'] != null ? 'Assist: ${goal['assist']['name']}' : goal['team']?['name'] ?? '',
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontFamily: 'Lexend'),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildLineups(Map<String, dynamic> matchData) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeTeam = matchData['homeTeam'];
    final awayTeam = matchData['awayTeam'];
    final homeLineup = homeTeam['lineup'] ?? [];
    final awayLineup = awayTeam['lineup'] ?? [];
    final homeBench = homeTeam['bench'] ?? [];
    final awayBench = awayTeam['bench'] ?? [];
    final homeFormation = homeTeam['formation'] ?? 'N/A';
    final awayFormation = awayTeam['formation'] ?? 'N/A';

    if (homeLineup.isEmpty && awayLineup.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Lineups will be available closer to kick-off.',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontFamily: 'Lexend',
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Map<String, List<Map<String, dynamic>>> groupPlayers(List<dynamic> players) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (var player in players) {
        final position = player['position'] ?? 'Unknown';
        grouped.putIfAbsent(position, () => []).add(player);
      }
      return grouped;
    }

    final homeGrouped = groupPlayers(homeLineup);
    final awayGrouped = groupPlayers(awayLineup);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lineups',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Lexend'),
          ),
          const SizedBox(height: 16),
          _buildTeamLineup(homeTeam['name'], homeFormation, homeGrouped, homeBench, colorScheme),
          const SizedBox(height: 16),
          _buildTeamLineup(awayTeam['name'], awayFormation, awayGrouped, awayBench, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTeamLineup(String teamName, String formation, Map<String, List<Map<String, dynamic>>> groupedLineup,
      List<dynamic> bench, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$teamName',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Lexend'),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    'Formation: $formation',
                    style: const TextStyle(fontFamily: 'Lexend'),
                  ),
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...groupedLineup.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontFamily: 'Lexend',
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...entry.value.map((player) => ListTile(
                          dense: true,
                          leading: Text(
                            '${player['shirtNumber'] ?? 'N/A'}',
                            style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Lexend'),
                          ),
                          title: Text(
                            player['name'] ?? 'Unknown',
                            style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Lexend'),
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],
                )),
            const Divider(),
            const Text(
              'Bench',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Lexend'),
            ),
            const SizedBox(height: 4),
            ...bench.map((player) => ListTile(
                  dense: true,
                  leading: Text(
                    '${player['shirtNumber'] ?? 'N/A'}',
                    style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Lexend'),
                  ),
                  title: Text(
                    player['name'] ?? 'Unknown',
                    style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Lexend'),
                  ),
                  subtitle: player['position'] != null
                      ? Text(
                          player['position'],
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontFamily: 'Lexend',
                          ),
                        )
                      : null,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEvents(Map<String, dynamic> matchData) {
    final colorScheme = Theme.of(context).colorScheme;
    final events = _compileEvents(matchData);

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            matchData['status'] == 'TIMED' || matchData['status'] == 'SCHEDULED'
                ? 'Events will be updated live during the match.'
                : 'No events recorded yet.',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontFamily: 'Lexend',
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: events.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Match Events',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Lexend'),
            ),
          );
        }
        final event = events[index - 1];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: _getEventIcon(event['type'], colorScheme),
            title: Text(
              '${event['minute'] ?? 'N/A'}\' - ${event['description']}',
              style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Lexend'),
            ),
            subtitle: Text(
              event['team'],
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontFamily: 'Lexend'),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _compileEvents(Map<String, dynamic> matchData) {
    final events = <Map<String, dynamic>>[];

    for (var goal in matchData['goals'] ?? []) {
      events.add({
        'type': 'goal',
        'minute': goal['minute'],
        'team': goal['team']['name'],
        'description': '${goal['scorer']['name']}${goal['assist'] != null ? ' (Assist: ${goal['assist']['name']})' : ''}',
      });
    }

    for (var penalty in matchData['penalties'] ?? []) {
      events.add({
        'type': 'penalty',
        'minute': penalty['minute'] ?? 0, // Assuming minute might be missing
        'team': penalty['team']['name'],
        'description': 'Penalty - ${penalty['player']['name']} (${penalty['scored'] ? 'Scored' : 'Missed'})',
      });
    }

    for (var booking in matchData['bookings'] ?? []) {
      events.add({
        'type': 'booking',
        'minute': booking['minute'],
        'team': booking['team']['name'],
        'description': '${booking['player']['name']} - ${booking['card']} Card',
      });
    }

    for (var sub in matchData['substitutions'] ?? []) {
      events.add({
        'type': 'substitution',
        'minute': sub['minute'],
        'team': sub['team']['name'],
        'description': '${sub['playerOut']['name']} → ${sub['playerIn']['name']}',
      });
    }

    events.sort((a, b) => (a['minute'] ?? 0).compareTo(b['minute'] ?? 0));
    return events;
  }

  Icon _getEventIcon(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'goal':
        return Icon(Icons.sports_soccer, color: Colors.green);
      case 'penalty':
        return Icon(Icons.flag, color: Colors.blue);
      case 'booking':
        return Icon(Icons.warning, color: Colors.yellow);
      case 'substitution':
        return Icon(Icons.swap_horiz, color: Colors.orange);
      default:
        return Icon(Icons.info, color: colorScheme.onSurface);
    }
  }
}