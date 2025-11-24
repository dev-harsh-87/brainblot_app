import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/sharing/domain/user_profile.dart';

class ProfileAvatar extends StatelessWidget {
  final UserProfile? userProfile;
  final double size;
  final bool showBorder;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isClickable;

  const ProfileAvatar({
    super.key,
    this.userProfile,
    this.size = 36,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.isClickable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppTheme.goldPrimary,
        border: showBorder ? Border.all(
          color: AppTheme.goldDeep,
          width: 2,
        ) : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.neutral900.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getProfileInitials(),
          style: TextStyle(
            color: textColor ?? AppTheme.whitePure,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );

    if (!isClickable) return avatar;

    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: avatar,
    );
  }

  String _getProfileInitials() {
    if (userProfile == null) return 'U';
    
    final displayName = userProfile!.displayName.trim();
    if (displayName.isEmpty) return 'U';
    
    final nameParts = displayName.split(' ').where((part) => part.isNotEmpty).toList();
    
    if (nameParts.isEmpty) return 'U';
    
    if (nameParts.length == 1) {
      // Single name - take first 2 characters
      final name = nameParts[0];
      return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    } else {
      // Multiple names - take first letter of first and last name
      final firstName = nameParts.first;
      final lastName = nameParts.last;
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
  }
}