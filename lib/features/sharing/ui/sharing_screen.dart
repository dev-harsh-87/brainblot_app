import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brainblot_app/features/sharing/domain/user_profile.dart';
import 'package:brainblot_app/features/sharing/services/sharing_service.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/core/widgets/confirmation_dialog.dart';

class SharingScreen extends StatefulWidget {
  final String itemType; // 'drill' or 'program'
  final String itemId;
  final String itemName;

  const SharingScreen({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> with SingleTickerProviderStateMixin {
  late final SharingService _sharingService;
  late final TabController _tabController;

  final _searchController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  List<UserProfile> _searchResults = [];
  List<UserProfile> _sharedUsers = [];

  bool _isSearching = false;
  bool _isLoadingShared = false;
  bool _isOwner = false;
  bool _privacyLoading = false;

  @override
  void initState() {
    super.initState();
    _sharingService = getIt<SharingService>();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSharedUsers(),
      _loadPrivacyInfo(),
    ]);
  }

  Future<void> _loadPrivacyInfo() async {
    try {
      final isOwner = await _sharingService.isOwner(widget.itemType, widget.itemId);

      if (mounted) {
        setState(() {
          _isOwner = isOwner;
        });
      }
    } catch (e) {
      print('Failed to load privacy info: $e');
    }
  }

  Future<void> _loadSharedUsers() async {
    setState(() => _isLoadingShared = true);

    try {
      print('📋 Loading shared users for ${widget.itemType} ${widget.itemId}');
      final users = await _sharingService.getSharedUsers(widget.itemType, widget.itemId);
      print('📋 Loaded ${users.length} shared users');

      if (mounted) {
        setState(() => _sharedUsers = users);
      }
    } catch (e) {
      print('❌ Failed to load shared users: $e');
      _showError('Failed to load shared users: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingShared = false);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _sharingService.searchUsers(query.trim());
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (e) {
      _showError('Search failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _shareWithUser(UserProfile user) async {
    try {
      print('🔄 Sharing ${widget.itemType} ${widget.itemId} with ${user.email}');

      if (widget.itemType == 'drill') {
        await _sharingService.shareDrill(widget.itemId, widget.itemName, user.id);
      } else {
        await _sharingService.shareProgram(widget.itemId, widget.itemName, user.id);
      }

      print('✅ Share completed, refreshing shared users list...');

      if (mounted) {
        _showSuccess('Shared with ${user.displayName}!');

        // Refresh shared users list
        await _loadSharedUsers();

        // Switch to "Shared" tab to show the result
        _tabController.animateTo(1);

        // Clear search
        _searchController.clear();
        setState(() => _searchResults = []);

        print('✅ Shared users refreshed. Count: ${_sharedUsers.length}');
      }
    } catch (e) {
      print('❌ Share error: $e');
      _showError('Failed to share: $e');
    }
  }

  Future<void> _removeUser(UserProfile user) async {
    try {
      print('🔄 Removing user ${user.displayName} (${user.id}) from ${widget.itemType} ${widget.itemId}');
      
      // Show loading state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Removing ${user.displayName}...'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Remove user from sharing
      await _sharingService.removeUserFromSharing(widget.itemType, widget.itemId, user.id);
      
      if (mounted) {
        // Clear any existing snackbars
        ScaffoldMessenger.of(context).clearSnackBars();
        
        _showSuccess('✅ ${user.displayName} no longer has access to this ${widget.itemType}');
        
        // Refresh the shared users list
        await _loadSharedUsers();
        
        print('✅ Successfully removed user ${user.displayName} from sharing');
      }
    } catch (e) {
      print('❌ Failed to remove user: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _showError('Failed to remove ${user.displayName}: $e');
      }
    }
  }

  Future<void> _shareViaEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter an email address');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email');
      return;
    }

    try {
      await _sharingService.shareViaEmail(
        email: email,
        itemType: widget.itemType,
        itemId: widget.itemId,
        itemName: widget.itemName,
        personalMessage: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
      );

      if (mounted) {
        _showSuccess('Email invitation sent! 📧');
        _emailController.clear();
        _messageController.clear();
      }
    } catch (e) {
      _showError('Failed to send email: $e');
    }
  }

  Future<void> _togglePrivacy() async {
    if (!_isOwner) return;

    // Show confirmation dialog
    final confirmed = await ConfirmationDialog.showPrivacyConfirmation(
      context,
      isCurrentlyPublic: false,
      itemType: widget.itemType,
      itemName: widget.itemName,
    );

    if (confirmed != true) return;

    setState(() => _privacyLoading = true);

    // Privacy toggle functionality removed - all items are now private
    if (mounted) {
      setState(() => _privacyLoading = false);
      
      _showSuccess('All items are private by default 🔒');
    }
  }


  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Handle keyboard properly
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Share ${widget.itemType.toUpperCase()}'),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              isScrollable: isSmallScreen,
              tabs: [
                Tab(icon: const Icon(Icons.person_add), text: isSmallScreen ? 'Add' : 'Add People'),
                const Tab(icon: Icon(Icons.group), text: 'Shared'),
                const Tab(icon: Icon(Icons.settings), text: 'Settings'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Item info card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            color: colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.itemType == 'drill' ? Icons.fitness_center : Icons.psychology,
                    color: colorScheme.onPrimary,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Private',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontSize: isSmallScreen ? 11 : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAddPeopleTab(),
                _buildSharedTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPeopleTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 
                     MediaQuery.of(context).viewInsets.bottom - 
                     kToolbarHeight - 
                     100, // Account for app bar and tabs
        ),
        child: Column(
          children: [
            // Search section - Fixed at top
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search by email or name',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter email or name...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    onChanged: (value) {
                      // Debounce search
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted && _searchController.text == value) {
                          _searchUsers(value);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // Results section - Flexible
            if (_searchResults.isEmpty)
              Container(
                height: 200,
                child: _buildEmptySearchState(),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final isAlreadyShared = _sharedUsers.any((u) => u.id == user.id);

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primary,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(user.email),
                      trailing: isAlreadyShared
                          ? Chip(
                              label: const Text('Shared'),
                              backgroundColor: Colors.green.withOpacity(0.1),
                              labelStyle: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              side: BorderSide.none,
                            )
                          : FilledButton.icon(
                              onPressed: () => _shareWithUser(user),
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchController.text.isEmpty ? Icons.search : Icons.person_off,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'Start searching for people'
                : 'No users found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _searchController.text.isEmpty
                  ? 'Enter an email or name to find people to share with'
                  : 'Try searching with a different email or name',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    if (_isLoadingShared) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sharedUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24.0 : 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_off,
                size: isSmallScreen ? 48 : 64,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Not shared yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: isSmallScreen ? 14 : null,
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Text(
                'Share this ${widget.itemType} with people to see them here',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontSize: isSmallScreen ? 12 : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSharedUsers,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sharedUsers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = _sharedUsers[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary,
                backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(user.email),
              trailing: IconButton(
                onPressed: () => _showRemoveDialog(user),
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                tooltip: 'Remove access',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Privacy toggle
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: false,
                onChanged: null,
                title: Text(
                  'Public ${widget.itemType.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'All items are private by default',
                ),
                secondary: const Icon(
                  Icons.lock,
                  color: Colors.grey,
                ),
              ),
              if (_privacyLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),

        if (!_isOwner) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Only the owner can change privacy settings',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Email invite section
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.email, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Invite via Email',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Send an invitation to someone who doesn\'t have the app yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter email address...',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _shareViaEmail,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Info cards
        _buildInfoCard(
          icon: Icons.lock,
          title: 'Private',
          description: 'Only you and people you explicitly share with can access this ${widget.itemType}. Great for personal content.',
          color: Colors.grey,
        ),

        const SizedBox(height: 12),

        _buildInfoCard(
          icon: Icons.public,
          title: 'Public',
          description: 'Anyone in the BrainBlot community can discover and use this ${widget.itemType}. Help others train better!',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveDialog(UserProfile user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Remove Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(text: 'Remove '),
                  TextSpan(
                    text: user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '\'s access to this ${widget.itemType}?'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'They will immediately lose access and won\'t be able to view or use this ${widget.itemType}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _removeUser(user);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_remove, size: 18),
                const SizedBox(width: 8),
                const Text('Remove Access'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

