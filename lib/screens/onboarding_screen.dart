import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';  // Add this import for ImageFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // Controller to keep track of which page we're on
  final PageController _controller = PageController();
  
  // Keep track of if we are on the last page
  bool isLastPage = false;
  
  // Animation controller for background
  late AnimationController _animationController;
  late Timer _timer;
  double _gradientValue = 0.0;

  // Background colors for animated gradient
  final List<Color> _colorsList = [
    const Color(0xFF5C6BC0), // Indigo
    const Color(0xFF7E57C2), // Deep Purple
    const Color(0xFF26A69A), // Teal
    const Color(0xFF42A5F5), // Blue
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
    
    // Timer to update gradient animation
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _gradientValue = (_gradientValue + 0.01) % 1;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    _timer.cancel();
    super.dispose();
  }

  // Method to save that onboarding is completed
  Future<void> _setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboardingCompleted', true);
  }

  // Method to navigate to permissions screen
  void _goToPermissions() {
    _setOnboardingComplete();
    Navigator.pushReplacementNamed(context, '/permissions');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          return Stack(
            children: [
              // Animated gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _colorsList[(_gradientValue * _colorsList.length).floor() % _colorsList.length],
                      _colorsList[((_gradientValue * _colorsList.length).floor() + 1) % _colorsList.length],
                      _colorsList[((_gradientValue * _colorsList.length).floor() + 2) % _colorsList.length],
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    transform: GradientRotation(_gradientValue * 2 * math.pi),
                  ),
                ),
              ),
              
              // Floating shape decorations
              ..._buildFloatingShapes(),
              
              // Main content with glassmorphism effect
              SafeArea(
                child: Stack(
                  children: [
                    // Page View for Slides with frosted glass effect
                    PageView(
                      controller: _controller,
                      onPageChanged: (index) {
                        setState(() {
                          isLastPage = (index == 2);
                        });
                      },
                      children: [
                        _buildOnboardingPage(
                          context,
                          title: 'Welcome to Storage Cleaner',
                          description: 'Keep your device clean and running smoothly with our powerful cleaning tools.',
                          icon: Icons.phone_android,
                        ),
                        _buildOnboardingPage(
                          context,
                          title: 'Smart Scanning',
                          description: 'Our intelligent scanner identifies junk files, cache, and unused apps taking up space.',
                          icon: Icons.search,
                        ),
                        _buildOnboardingPage(
                          context,
                          title: 'One-Tap Cleaning',
                          description: 'Remove unwanted files with a single tap and enjoy a faster, more efficient device.',
                          icon: Icons.cleaning_services,
                        ),
                      ],
                    ),
                    
                    // Skip button at top right with glass effect
                    Positioned(
                      top: 16,
                      right: 16,
                      child: isLastPage ? const SizedBox() : _GlassmorphicContainer(
                        child: TextButton(
                          onPressed: _goToPermissions,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        borderRadius: 20,
                        width: 80,
                        height: 40,
                      ),
                    ),
                    
                    // Bottom navigation - Dot indicators and Next button
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Dot indicators with glass effect
                            _GlassmorphicContainer(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: SmoothPageIndicator(
                                  controller: _controller,
                                  count: 3,
                                  effect: WormEffect(
                                    activeDotColor: Colors.white,
                                    dotColor: Colors.white.withOpacity(0.5),
                                    dotHeight: 10,
                                    dotWidth: 10,
                                  ),
                                ),
                              ),
                              borderRadius: 20,
                              width: 100,
                              height: 40,
                            ),
                            
                            // Next or Get Started button with modern glass effect
                            _GlassmorphicContainer(
                              child: ElevatedButton(
                                onPressed: isLastPage
                                    ? _goToPermissions
                                    : () {
                                        _controller.nextPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  isLastPage ? 'Get Started' : 'Next',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              borderRadius: 20,
                              width: 140,
                              height: 50,
                              opacity: 0.1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper method to build floating shapes for background
  List<Widget> _buildFloatingShapes() {
    final List<Widget> shapes = [];
    final random = math.Random(42); // Fixed seed for consistent results

    // Create several floating shapes
    for (int i = 0; i < 12; i++) {
      final double size = random.nextDouble() * 100 + 50;
      final double left = random.nextDouble() * MediaQuery.of(context).size.width;
      final double top = random.nextDouble() * MediaQuery.of(context).size.height;
      final double opacity = random.nextDouble() * 0.2 + 0.05;
      final double angle = random.nextDouble() * math.pi * 2;
      
      // Animate position with sin/cos
      final double offsetX = 20 * math.sin(_animationController.value * math.pi * 2 + i);
      final double offsetY = 20 * math.cos(_animationController.value * math.pi * 2 + i);

      shapes.add(
        Positioned(
          left: left + offsetX,
          top: top + offsetY,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                borderRadius: BorderRadius.circular(i % 2 == 0 ? size / 2 : size / 4),
              ),
            ),
          ),
        ),
      );
    }
    
    return shapes;
  }

  // Helper method to build individual onboarding pages
  Widget _buildOnboardingPage(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: _GlassmorphicContainer(
        width: double.infinity,
        height: 500,
        borderRadius: 30,
        opacity: 0.15,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Illustration placeholder with animated container
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(75),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 50),
              
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black26,
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  height: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black12,
                      offset: Offset(0.5, 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Glassmorphism container widget
class _GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final double borderRadius;
  final double opacity;

  const _GlassmorphicContainer({
    required this.child,
    required this.width,
    required this.height,
    this.borderRadius = 20,
    this.opacity = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(opacity + 0.05),
                Colors.white.withOpacity(opacity),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
