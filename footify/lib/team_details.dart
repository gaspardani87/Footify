import 'package:flutter/material.dart';
import 'common_layout.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TeamDetailsPage extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailsPage({
    super.key, 
    required this.teamId, 
    required this.teamName
  });

  @override
  _TeamDetailsPageState createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  int _currentTab = 0;
  final List<String> _tabs = ['Overview', 'Stats', 'Squad', 'Matches'];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CommonLayout(
      showBackButton: true,
      selectedIndex: -1, // -1 since this isn't a main navigation page
      child: Column(
        children: [
          // Team header with name and logo
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.teamName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab navigation
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1D1D1D) : Colors.grey[200],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentTab;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _currentTab = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? const Color(0xFFFFE6AC) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFFFE6AC) : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Content area
          Expanded(
            child: Center(
              child: Text(
                'Team details for ${widget.teamName} (ID: ${widget.teamId}) will be shown here.\nThis page is under development.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 