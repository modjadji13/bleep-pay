import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ble_service.dart';
import '../core/ws_client.dart';
import '../state/auth_provider.dart';
import 'send_sheet.dart';
import 'request_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // Pulsing animation for the ready indicator
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Listen for WebSocket events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(wsClientProvider);
      ws?.onEvent = (event) {
        if (!mounted) return;
        if (event.type == WsEventType.paymentRequest) {
          // Someone is sending us money - show the accept sheet
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => RequestSheet(event: event),
          );
        } else if (event.type == WsEventType.paymentCompleted) {
          final amount = (event.data['amount_cents'] is int)
              ? (event.data['amount_cents'] as int) / 100
              : ((event.data['amount_cents'] as num?)?.toDouble() ?? 0) / 100;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment completed! +R${amount.toStringAsFixed(2)}'),
              backgroundColor: const Color(0xFF00F5A0),
            ),
          );
        }
      };
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nearbyUsers = ref.watch(bleProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bleep Pay', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                      const Text(
                        'Ready to tap',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.logout, color: Colors.white.withOpacity(0.4)),
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Pulse indicator
            Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    Container(
                      width: 200 * _pulse.value,
                      height: 200 * _pulse.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00F5A0).withOpacity(0.05),
                        border: Border.all(
                          color: const Color(0xFF00F5A0).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    // Inner ring
                    Container(
                      width: 140 * _pulse.value,
                      height: 140 * _pulse.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00F5A0).withOpacity(0.08),
                        border: Border.all(
                          color: const Color(0xFF00F5A0).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                    ),
                    // Center dot
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00F5A0)),
                      child: const Icon(Icons.bolt, color: Colors.black, size: 36),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Nearby users section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                nearbyUsers.isEmpty ? 'Scanning for nearby users...' : '${nearbyUsers.length} nearby',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
            ),

            const SizedBox(height: 12),

            // Nearby user list
            Expanded(
              child: nearbyUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bluetooth_searching, color: Colors.white.withOpacity(0.15), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Bring phones close together',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: nearbyUsers.length,
                      itemBuilder: (_, i) {
                        final user = nearbyUsers[i];
                        return _NearbyUserCard(
                          user: user,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => SendSheet(toUser: user),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyUserCard extends StatelessWidget {
  final NearbyUser user;
  final VoidCallback onTap;

  const _NearbyUserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E1E2E)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00F5A0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline, color: Color(0xFF00F5A0), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.deviceName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to send money',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.2), size: 14),
          ],
        ),
      ),
    );
  }
}
