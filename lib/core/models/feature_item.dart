import 'package:flutter/material.dart';

/// Models a single feature showcase in the app.
class FeatureItem {
  final String title;
  final IconData icon;
  final String description;
  final WidgetBuilder builder;

  const FeatureItem({
    required this.title,
    required this.icon,
    required this.description,
    required this.builder,
  });
}
