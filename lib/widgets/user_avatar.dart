import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final double radius;

  const UserAvatar({
    super.key,
    required this.username,
    this.photoUrl,
    this.radius = 20.0,
  });

  String get _getInitials {
    if (username.isEmpty) return '?';
    return username[0].toUpperCase();
  }

  Color get _getBackgroundColor {
    final hash = username.hashCode;
    final colors = [
      Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.cyan,
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = photoUrl != null && photoUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _getBackgroundColor,
      backgroundImage: hasImage ? NetworkImage(photoUrl!) : null,
      child: !hasImage
          ? Text(
              _getInitials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.9,
              ),
            )
          : null,
    );
  }
}
