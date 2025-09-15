import 'package:flutter/material.dart';

class HomeTileData {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;

  const HomeTileData({
    required this.title,
    required this.icon,
    required this.color,
    required this.page,
  });
}
