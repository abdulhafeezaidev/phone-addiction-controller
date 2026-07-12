import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/focus_providers.dart';
import '../../../../domain/models/allowed_app.dart';

class AppDrawerOverlay extends ConsumerStatefulWidget {
  final bool isShown;
  final VoidCallback onClose;

  const AppDrawerOverlay({
    super.key,
    required this.isShown,
    required this.onClose,
  });

  @override
  ConsumerState<AppDrawerOverlay> createState() => _AppDrawerOverlayState();
}

class _AppDrawerOverlayState extends ConsumerState<AppDrawerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _platformChannel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Slide up from the bottom
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.isShown) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AppDrawerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShown != oldWidget.isShown) {
      if (widget.isShown) {
        // Reset search query when opened
        _searchController.clear();
        setState(() => _searchQuery = '');
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.isShown) return;
    final screenHeight = MediaQuery.of(context).size.height;
    // details.primaryDelta is positive when swiping down.
    // So swiping down increases the offset towards 1.0 (hidden).
    _animationController.value -= details.primaryDelta! / screenHeight;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.isShown) return;
    final velocity = details.primaryVelocity ?? 0.0;
    // Positive velocity means moving down
    if (velocity > 300 || _animationController.value < 0.6) {
      widget.onClose();
    } else {
      _animationController.forward();
    }
  }

  Future<void> _launchApp(AllowedApp app) async {
    try {
      await _platformChannel.invokeMethod(
        'launchApp',
        {'packageName': app.packageName},
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${app.appName}: ${e.message ?? e.code}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.isShown && !_animationController.isAnimating,
      child: Stack(
        children: [
          // Fade backdrop
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          
          // Slide-up drawer
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: GestureDetector(
                onVerticalDragUpdate: _handleDragUpdate,
                onVerticalDragEnd: _handleDragEnd,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.9,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24).withValues(alpha: 0.85),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          // Drag handle
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Search Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search apps...',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // App Grid
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, child) {
                                final installedAppsAsync = ref.watch(installedAppsProvider(true));
                                
                                return installedAppsAsync.when(
                                  data: (apps) {
                                    final filteredApps = apps.where((app) {
                                      return app.appName.toLowerCase().contains(_searchQuery);
                                    }).toList()
                                      ..sort((a, b) => a.appName.compareTo(b.appName));

                                    if (filteredApps.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No apps found',
                                          style: TextStyle(color: Colors.white54),
                                        ),
                                      );
                                    }

                                    return GridView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        mainAxisSpacing: 24,
                                        crossAxisSpacing: 16,
                                        childAspectRatio: 0.75,
                                      ),
                                      itemCount: filteredApps.length,
                                      itemBuilder: (context, index) {
                                        final app = filteredApps[index];
                                        return GestureDetector(
                                          onTap: () => _launchApp(app),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Expanded(
                                                child: CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                                  child: app.icon != null
                                                      ? Image.memory(app.icon!, width: 40, height: 40)
                                                      : const Icon(Icons.apps, color: Colors.white54),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                app.appName,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (_, __) => const Center(child: Text('Error loading apps')),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
