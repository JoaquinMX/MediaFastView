import 'package:flutter/material.dart';

import '../models/directory_navigation_target.dart';
import '../screens/media_grid_screen.dart';

class MediaNavigationHandler {
  MediaNavigationHandler({
    List<DirectoryNavigationTarget>? siblings,
    int? currentIndex,
  }) {
    updateNavigationContext(siblings, currentIndex);
  }

  List<DirectoryNavigationTarget> _siblingNavigationTargets = const [];
  int _currentDirectoryNavigationIndex = 0;

  List<DirectoryNavigationTarget> get siblingNavigationTargets =>
      _siblingNavigationTargets;
  int get currentDirectoryNavigationIndex => _currentDirectoryNavigationIndex;
  bool get hasSiblingNavigation => _siblingNavigationTargets.length > 1;
  bool get canNavigateToPrevious => _currentDirectoryNavigationIndex > 0;
  bool get canNavigateToNext =>
      _currentDirectoryNavigationIndex < _siblingNavigationTargets.length - 1;

  void updateNavigationContext(
    List<DirectoryNavigationTarget>? siblings,
    int? currentIndex,
  }) {
    _siblingNavigationTargets = List<DirectoryNavigationTarget>.from(
      siblings ?? const [],
    );
    if (_siblingNavigationTargets.isEmpty) {
      _currentDirectoryNavigationIndex = 0;
      return;
    }

    final maxIndex = _siblingNavigationTargets.length - 1;
    final safeIndex = (currentIndex ?? 0).clamp(0, maxIndex);
    _currentDirectoryNavigationIndex = safeIndex;
  }

  void navigateToSibling(
    BuildContext context,
    int offset,
    void Function(DirectoryNavigationTarget target, int targetIndex) onNavigate,
  ) {
    if (_siblingNavigationTargets.length < 2) {
      return;
    }

    final targetIndex = _currentDirectoryNavigationIndex + offset;
    if (targetIndex < 0 || targetIndex >= _siblingNavigationTargets.length) {
      return;
    }

    final target = _siblingNavigationTargets[targetIndex];
    onNavigate(target, targetIndex);
  }

  void handleSwipe(
    DragEndDetails details,
    BuildContext context,
    void Function(DirectoryNavigationTarget target, int targetIndex) onNavigate,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -100) {
      navigateToSibling(context, 1, onNavigate);
    } else if (velocity > 100) {
      navigateToSibling(context, -1, onNavigate);
    }
  }

  PageRouteBuilder<dynamic> buildNavigationRoute({
    required MediaGridScreen destination,
    required bool isBackwardNavigation,
  }) {
    final beginOffset = isBackwardNavigation
        ? const Offset(-1, 0)
        : const Offset(1, 0);

    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: beginOffset,
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOutCubic));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  bool isBackwardNavigation(int? targetIndex) {
    if (!hasSiblingNavigation) {
      return false;
    }
    return (targetIndex ?? _currentDirectoryNavigationIndex) <
        _currentDirectoryNavigationIndex;
  }
}
