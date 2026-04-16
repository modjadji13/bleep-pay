import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/ws_client.dart';

class RequestSheet extends ConsumerStatefulWidget {
  final WsEvent event;

  const RequestSheet({super.key, required this.event});

  @override
  ConsumerState<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<RequestSheet> {
  bool _loading = false;
  bool _done = false;
  bool _accepted = false;

  String get paymentId => (widget.event.data['payment_id'] ?? '').toString();
  int get amountCents {
    final value = widget.event.data['amount_cents'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String get fromUser => (widget.event.data['from_user'] ?? 'unknown').toString();
  double get amountRands => amountCents / 100;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).acceptPayment(paymentId);
      setState(() {
        _done = true;
        _accepted = true;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).declinePayment(paymentId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 32),

          if (_done) ...[
            Icon(
              _accepted ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: _accepted ? const Color(0xFF00F5A0) : Colors.redAccent,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              _accepted ? 'Payment accepted!' : 'Payment declined',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ] else ...[
            // Incoming indicator
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF00F5A0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_downward, color: Color(0xFF00F5A0), size: 28),
            ),

            const SizedBox(height: 20),

            const Text('Incoming payment', style: TextStyle(color: Colors.white54, fontSize: 14)),

            const SizedBox(height: 8),

            Text(
              'R${amountRands.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'from ${fromUser.length >= 8 ? '${fromUser.substring(0, 8)}...' : fromUser}',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),

            const SizedBox(height: 40),

            // Accept button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F5A0),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 12),

            // Decline button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: _loading ? null : _decline,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Decline', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
