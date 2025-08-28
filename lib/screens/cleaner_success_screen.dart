import 'package:flutter/material.dart';
import 'dart:math' as math;

class CleanerSuccessScreen extends StatefulWidget {
  const CleanerSuccessScreen({super.key});

  @override
  State<CleanerSuccessScreen> createState() => _CleanerSuccessScreenState();
}

class _CleanerSuccessScreenState extends State<CleanerSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Scale animation for checkmark
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    // Rotation animation for particles
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the animation
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get arguments (cleaned size and items count)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final cleanedSize = args['cleanedSize'] as double? ?? 0.0;
    final itemsCount = args['itemsCount'] as int? ?? 0;
    
    // Format cleaned size
    String formattedSize;
    if (cleanedSize < 1024) {
      formattedSize = '${cleanedSize.toStringAsFixed(1)} B';
    } else if (cleanedSize < 1024 * 1024) {
      formattedSize = '${(cleanedSize / 1024).toStringAsFixed(1)} KB';
    } else if (cleanedSize < 1024 * 1024 * 1024) {
      formattedSize = '${(cleanedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      formattedSize = '${(cleanedSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating particles
                    AnimatedBuilder(
                      animation: _rotateAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotateAnimation.value,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                            ),
                            child: Stack(
                              children: List.generate(12, (index) {
                                final angle = (index / 12) * 2 * math.pi;
                                final radius = 100.0;
                                final x = radius * math.cos(angle);
                                final y = radius * math.sin(angle);
                                
                                return Positioned(
                                  left: 110 + x - 5,
                                  top: 110 + y - 5,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Success checkmark
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 80,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Success text and info
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Cleaning Complete!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Successfully cleaned $formattedSize of storage',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$itemsCount items removed',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context, 
                        '/home', 
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Return to Home',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
}
