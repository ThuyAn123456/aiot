import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/models/node_model.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/node_card.dart';
import '../widgets/stat_card.dart';
import '../../auth/screens/login_screen.dart';
import 'kitchen_living_screen.dart';
import 'bedroom_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Fetch nodes on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().fetchNodes();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Bạn có chắc muốn đăng xuất không?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _showAddNodeDialog() {
    final nameController = TextEditingController();
    final chipIdController = TextEditingController();
    String selectedTemplate = 'kitchen_living';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Thêm Thiết Bị Mới', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tên phòng (VD: Bếp tầng 1)',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: chipIdController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Mã Chip ID (VD: esp_123)',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Chọn mẫu:', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedTemplate,
                dropdownColor: AppTheme.bgDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'kitchen_living', child: Text('Bếp & Khách')),
                  DropdownMenuItem(value: 'bedroom', child: Text('Phòng Ngủ')),
                ],
                onChanged: (val) {
                  setState(() {
                    selectedTemplate = val!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final chipId = chipIdController.text.trim();
                if (name.isNotEmpty && chipId.isNotEmpty) {
                  context.read<DeviceProvider>().addNode(name, chipId, selectedTemplate);
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cụm icon được thiết kế dạng neumorphism / glassmorphism
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.15),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.devices_other_rounded,
                size: 80,
                color: AppTheme.primaryLight,
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.05, duration: 2.seconds),
            
            const SizedBox(height: 32),
            
            const Text(
              'Ngôi nhà chưa có thiết bị',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 12),
            
            const Text(
              'Hãy bắt đầu kết nối không gian sống của bạn bằng cách thêm một trạm (Node) điều khiển thông minh mới.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 40),
            
            GestureDetector(
              onTap: _showAddNodeDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Thêm Thiết Bị',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).scale(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final devices = context.watch<DeviceProvider>();
    final nodes = devices.nodes;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1130), Color(0xFF0A0E21)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hệ thống IoT',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn().slideX(begin: -0.2),
                      Row(
                        children: [
                          if (nodes.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 28),
                              onPressed: _showAddNodeDialog,
                            ).animate().fadeIn().scale(delay: 100.ms),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _handleLogout,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primary.withOpacity(0.2),
                              child: Text(
                                (user?.name ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ).animate().fadeIn().scale(delay: 200.ms),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // ── Node List or Empty State ──────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: nodes.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final node = nodes[index];
                          return NodeCard(
                            node: node,
                            onTapManage: () {
                              if (!node.isOnline) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Thiết bị ${node.name} đang Offline!'),
                                    backgroundColor: AppTheme.warning,
                                  ),
                                );
                                return;
                              }
                              if (node.templateType == 'kitchen_living') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => KitchenLivingScreen(nodeId: node.id)));
                              } else if (node.templateType == 'bedroom') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => BedroomScreen(nodeId: node.id)));
                              }
                            },
                            onDelete: () {
                              devices.removeNode(node.id);
                            },
                          ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.2);
                        },
                        childCount: nodes.length,
                      ),
                    ),
              ),

              // Bottom padding
              Builder(
                builder: (ctx) => SliverToBoxAdapter(
                  child: SizedBox(height: R.bottom(ctx) + 32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

