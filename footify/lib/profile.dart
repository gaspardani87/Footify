import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_layout.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'providers/firebase_provider.dart';
import 'package:flutter/services.dart';
import 'services/football_api_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Color goldColor = Color(0xFFFFD700);
  static const Color darkColor = Color(0xFF2C2C2C);

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      selectedIndex: 3,
      child: Consumer<FirebaseProvider>(
        builder: (context, provider, _) {
          final user = provider.currentUser;

          // If not logged in, show login/register buttons
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome to Footify!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please log in or register to access your profile',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildLoginButton(context),
                    const SizedBox(height: 16),
                    _buildRegisterButton(context),
                  ],
                ),
              ),
            );
          }

          // User is logged in, show profile layout with logout button
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile data section
                        if (provider.userData != null) ...[
                          _buildProfileData(context, provider.userData!),
                        ] else ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Error loading profile data',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Logout button always visible when logged in
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await provider.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: darkColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 16,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _showDeleteAccountDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 16,
                    ),
                    side: const BorderSide(color: Colors.red),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileData(BuildContext context, Map<String, dynamic> userData) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: goldColor,
          child: Icon(Icons.person, size: 50, color: darkColor),
        ),
        const SizedBox(height: 12),
        Text(
          '@${userData['username'] ?? 'username'}',
          style: const TextStyle(
            color: goldColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Joined ${_formatDate(userData['joinDate'] ?? DateTime.now())}',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Card(
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileItem(
                  context,
                  'Email',
                  userData['email'] ?? 'No email provided',
                  Icons.email,
                ),
                const Divider(color: Colors.grey),
                _buildProfileItem(
                  context,
                  'Name',
                  userData['name'] ?? 'No name provided',
                  Icons.person,
                ),
                const Divider(color: Colors.grey),
                _buildProfileItem(
                  context,
                  'Phone',
                  userData['phoneNumber']?.isEmpty ?? true
                      ? 'No phone provided'
                      : userData['phoneNumber'],
                  Icons.phone,
                ),
                const Divider(color: Colors.grey),
                _buildProfileItem(
                  context,
                  'Favorite Team',
                  userData['favoriteTeam'] ?? 'No team selected',
                  Icons.sports_soccer,
                ),
                const Divider(color: Colors.grey),
                _buildProfileItem(
                  context,
                  'Favorite League',
                  userData['favoriteLeague'] ?? 'No league selected',
                  Icons.emoji_events,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showLoginDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: goldColor,
        foregroundColor: darkColor,
        padding: const EdgeInsets.symmetric(
          horizontal: 50,
          vertical: 16,
        ),
        shape: const StadiumBorder(),
      ),
      child: const Text(
        'Login',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _showRegistrationFlow(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: goldColor,
        padding: const EdgeInsets.symmetric(
          horizontal: 50,
          vertical: 16,
        ),
        side: const BorderSide(color: goldColor),
        shape: const StadiumBorder(),
      ),
      child: const Text(
        'Register',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: goldColor, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRegistrationFlow(BuildContext context) async {
    // Step 1: Email and Password
    final credentials = await _showEmailPasswordDialog(context);
    if (credentials == null) return;

    // Step 2: Full Name
    final name = await _showNameDialog(context);
    if (name == null) return;

    // Step 3: Username
    final username = await _showUsernameDialog(context);
    if (username == null) return;

    // Step 4: Phone Number (Optional)
    final phoneNumber = await _showPhoneDialog(context);
    // Note: phoneNumber can be null as it's optional

    // Step 5: Favorite Team
    final team = await _showTeamSelectionDialog(context);
    if (team == null) return;

    // Step 6: Favorite League
    final league = await _showLeagueSelectionDialog(context);
    if (league == null) return;

    // Complete Registration
    if (context.mounted) {
      final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
      try {
        final success = await firebaseProvider.completeSignUp(
          name: name,
          username: username,
          phoneNumber: phoneNumber ?? '',
          favoriteTeam: team['name'] ?? '',
          favoriteLeague: league['name'] ?? '',
        );

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration completed successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<Map<String, String>?> _showEmailPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
                obscureText: true,
                enabled: !isLoading,
              ),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                obscureText: true,
                enabled: !isLoading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        final firebaseProvider =
                            Provider.of<FirebaseProvider>(context, listen: false);
                        final success = await firebaseProvider.initiateSignUp(
                          emailController.text,
                          passwordController.text,
                        );

                        if (success) {
                          Navigator.pop(context, {
                            'email': emailController.text,
                            'password': passwordController.text,
                          });
                        } else {
                          setState(() => isLoading = false);
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNameDialog(BuildContext context) async {
    final nameController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Full Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showUsernameDialog(BuildContext context) async {
    final usernameController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Username'),
        content: TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () {
              if (usernameController.text.isNotEmpty) {
                Navigator.pop(context, usernameController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a username')),
                );
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPhoneDialog(BuildContext context) async {
    final phoneController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Phone Number (Optional)'),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, phoneController.text),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showTeamSelectionDialog(BuildContext context) async {
    final footballApiService = FootballApiService();
    List<Map<String, String>>? teams;
    Map<String, String>? selectedTeam;
    bool isLoading = true;

    try {
      teams = await footballApiService.getTeams();
      isLoading = false;
    } catch (e) {
      print('Error loading teams: $e');
      isLoading = false;
    }

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Your Favorite Team'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const CircularProgressIndicator()
                else if (teams == null || teams.isEmpty)
                  const Text('Failed to load teams')
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1,
                      ),
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final team = teams![index];
                        final isSelected = selectedTeam == team;
                        return InkWell(
                          onTap: () {
                            setState(() => selectedTeam = team);
                          },
                          child: Card(
                            color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  team['crest'] ?? '',
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.sports_soccer),
                                ),
                                Text(
                                  team['name'] ?? 'Unknown Team',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: isLoading || selectedTeam == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedTeam),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>?> _showLeagueSelectionDialog(BuildContext context) async {
    final footballApiService = FootballApiService();
    List<Map<String, String>>? leagues;
    Map<String, String>? selectedLeague;
    bool isLoading = true;

    try {
      leagues = await footballApiService.getLeagues();
      isLoading = false;
    } catch (e) {
      print('Error loading leagues: $e');
      isLoading = false;
    }

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Your Favorite League'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const CircularProgressIndicator()
                else if (leagues == null || leagues.isEmpty)
                  const Text('Failed to load leagues')
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1,
                      ),
                      itemCount: leagues.length,
                      itemBuilder: (context, index) {
                        final league = leagues![index];
                        final isSelected = selectedLeague == league;
                        return InkWell(
                          onTap: () {
                            setState(() => selectedLeague = league);
                          },
                          child: Card(
                            color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  league['emblem'] ?? '',
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.emoji_events),
                                ),
                                Text(
                                  league['name'] ?? 'Unknown League',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: isLoading || selectedLeague == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedLeague),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLoginDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                ),
                obscureText: true,
                enabled: !isLoading,
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final firebaseProvider =
                            Provider.of<FirebaseProvider>(context, listen: false);
                        final success = await firebaseProvider.signIn(
                          emailController.text,
                          passwordController.text,
                        );

                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Login successful'),
                            ),
                          );
                        } else if (context.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Login failed'),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteAccount(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
    try {
      await firebaseProvider.deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}