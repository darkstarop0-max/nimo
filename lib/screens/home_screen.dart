import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Animation controllers
  late final AnimationController _progressController;
  late final AnimationController _cardsController;
  late Animation<double> _progressAnimation;
  
  // Storage data
  double _totalStorage = 0.0; // GB
  double _usedStorage = 0.0; // GB
  double _freeStorage = 0.0; // GB
  double _usedPercentage = 0.0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Bottom navigation index
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize progress animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0, // Will be updated when data is loaded
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    
    // Initialize cards animation
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Load storage data
    _loadStorageData();
    
    // Start cards animation
    _cardsController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _cardsController.dispose();
    super.dispose();
  }
  
  // Method to load storage data
  Future<void> _loadStorageData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      if (Platform.isAndroid) {
        await _loadAndroidStorageData();
      } else {
        // For iOS and other platforms, use a different approach
        await _loadGenericStorageData();
      }
      
      // Recreate the animation with the actual value
      _progressAnimation = Tween<double>(
        begin: 0.0,
        end: _usedPercentage,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
      
      // Reset and start the progress animation
      _progressController.reset();
      _progressController.forward();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error loading storage data: ${e.toString()}';
      });
    }
  }
  
  // Load storage data specifically for Android devices
  Future<void> _loadAndroidStorageData() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    // We get the device info but don't directly use it for storage
    // This could be used in a more advanced implementation
    await deviceInfo.androidInfo;
    
    // For most Android devices, we won't get disk space info directly
    // So let's use a more reliable approach with path_provider
    await _loadGenericStorageData();
  }
  
  // Generic approach to estimate storage for all platforms
  Future<void> _loadGenericStorageData() async {
    // We check for storage directory but use simulated values for this demo
    await getExternalStorageDirectory() ?? 
         await getApplicationDocumentsDirectory();
    
    // Get free space from directory
    try {
      // For this implementation, we'll simulate real values
      // In a real app, you would use platform-specific code or plugins
      // to get accurate storage information
      
      // These values are simulated
      _totalStorage = 128.0; // Simulate 128 GB total storage
      _freeStorage = 55.5; // Simulate 55.5 GB free
      _usedStorage = _totalStorage - _freeStorage;
      _usedPercentage = _usedStorage / _totalStorage;
    } catch (e) {
      throw Exception('Failed to load storage info: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF4776E6), Color(0xFF8E54E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Storage Cleaner',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2.0,
                  color: Color.fromRGBO(0, 0, 0, 0.3),
                ),
              ],
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageData,
            tooltip: 'Refresh storage data',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Storage usage circle indicator
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: _buildStorageIndicator(),
              ),
              
              // Action cards
              _buildActionCards(),
              
              // Bottom padding to avoid FAB overlap
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/scan');
        },
        icon: const Icon(Icons.flash_on),
        label: const Text('Quick Scan'),
        elevation: 4,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Widget for circular storage usage indicator
  Widget _buildStorageIndicator() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading storage data...'),
          ],
        ),
      );
    }
    
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStorageData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return Center(
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CustomPaint(
              foregroundPainter: CircleProgressPainter(
                progress: _progressAnimation.value,
                strokeWidth: 25.0,
                gradientColors: const [
                  Color(0xFF4776E6), // Blue
                  Color(0xFF8E54E9), // Purple
                  Color(0xFF2FDAD8), // Teal
                ],
              ),
              child: Container(
                width: 260,
                height: 260,
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_usedStorage.toStringAsFixed(1)} GB',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'of ${_totalStorage.toStringAsFixed(1)} GB used',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Montserrat',
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          '${_freeStorage.toStringAsFixed(1)} GB free',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Montserrat',
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget for action cards in a grid
  Widget _buildActionCards() {
    // Card data
    final List<Map<String, dynamic>> cards = [
      {
        'title': 'Junk Cleaner',
        'icon': Icons.delete_outline,
        'color': Colors.orange,
      },
      {
        'title': 'Duplicate Files',
        'icon': Icons.file_copy_outlined,
        'color': Colors.green,
      },
      {
        'title': 'Large Files',
        'icon': Icons.insert_drive_file_outlined,
        'color': Colors.blue,
      },
      {
        'title': 'Cache Cleaner',
        'icon': Icons.cached,
        'color': Colors.purple,
      },
    ];

    return AnimatedBuilder(
      animation: _cardsController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.2,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              // Staggered animation for each card
              final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _cardsController,
                  curve: Interval(
                    0.1 * index,
                    0.1 * index + 0.6,
                    curve: Curves.easeOut,
                  ),
                ),
              );
              
              return _buildCard(
                cards[index]['title'],
                cards[index]['icon'],
                cards[index]['color'],
                animation,
              );
            },
          ),
        );
      },
    );
  }
  
  // Individual card widget with animation
  Widget _buildCard(String title, IconData icon, Color color, Animation<double> animation) {
    return ScaleTransition(
      scale: animation,
      child: FadeTransition(
        opacity: animation,
        child: Card(
          elevation: 4,
          shadowColor: color.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/scan');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.9),
                          color,
                        ],
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Bottom navigation bar
  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotch(),
      elevation: 8,
      notchMargin: 8,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: IconButton(
                icon: Icon(
                  Icons.home,
                  color: _selectedIndex == 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
            ),
            const SizedBox(width: 48), // Space for FAB
            Expanded(
              child: IconButton(
                icon: Icon(
                  Icons.settings,
                  color: _selectedIndex == 2
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom notched shape for BottomAppBar
class CircularNotch extends NotchedShape {
  const CircularNotch();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) return Path()..addRect(host);

    final notchRadius = guest.width / 2.0;
    final r = notchRadius;
    final a = -math.pi / 2;
    final b = math.pi / 2;

    final path = Path();
    path.addRect(host);

    final centerX = guest.center.dx;
    final centerY = guest.center.dy;

    path.addArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: r),
      a,
      b - a,
    );

    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(path, Offset.zero);
  }
}

// Custom painter for circle progress
class CircleProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final List<Color> gradientColors;

  CircleProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - strokeWidth / 2;

    // Create gradient
    final gradient = SweepGradient(
      colors: gradientColors,
      startAngle: 3 * math.pi / 2,
      endAngle: 7 * math.pi / 2,
      tileMode: TileMode.repeated,
    );

    // Create background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Create foreground arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final foregroundPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the arc
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gradientColors != gradientColors;
  }
}
