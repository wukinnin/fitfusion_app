import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import 'knight_disposition.dart';
import 'knight_service.dart';

/// Home-screen Knight avatar + speech-bubble card. Mimics the FB/IG
/// "Note" style: a parchment bubble above a circular gold-ringed portrait.
///
/// Evaluates the current disposition once per build and picks a fresh line
/// from that disposition's pool. A new line is drawn each time the home
/// screen rebuilds (matching the spec: "randomly selected for every
/// homescreen load").
class KnightCard extends StatefulWidget {
  final String userId;

  const KnightCard({super.key, required this.userId});

  @override
  State<KnightCard> createState() => _KnightCardState();
}

class _KnightCardState extends State<KnightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KnightDisposition>(
      future: KnightService.evaluate(widget.userId),
      builder: (context, snapshot) {
        final disposition = snapshot.data ?? KnightDisposition.praise;
        final line = KnightService.pickRandomLine(disposition);
        return FutureBuilder<String?>(
          future: _fetchUsername(),
          builder: (context, usernameSnapshot) {
            return FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: _buildCard(disposition, line, usernameSnapshot.data),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _fetchUsername() async {
    final client = Supabase.instance.client;
    try {
      final row = await client
          .from('users')
          .select('username')
          .eq('id', widget.userId)
          .maybeSingle();
      return row?['username'] as String?;
    } catch (_) {
      return null;
    }
  }

  Widget _buildCard(KnightDisposition disposition, String line, String? username) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SpeechBubble(line: line),
        const SizedBox(height: 8),
        _AvatarCircle(assetPath: disposition.assetPath),
        if (username != null) ...[
          const SizedBox(height: 6),
          Text(
            username,
            style: GoogleFonts.cinzel(
              color: AppTheme.gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

/// Parchment-style speech bubble with a downward tail. Auto-sizes to its
/// text content and stays readable from a distance.
class _SpeechBubble extends StatelessWidget {
  final String line;
  const _SpeechBubble({required this.line});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320, minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.parchment,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.gold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                color: AppTheme.bloodRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ),
        // Tail (small downward triangle pointing at the avatar)
        Positioned(
          bottom: 0,
          child: CustomPaint(
            size: const Size(18, 14),
            painter: _BubbleTailPainter(),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppTheme.parchment
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppTheme.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, fill);
    // Only stroke the two angled sides — the top edge sits flush with
    // the bubble and shouldn't show a seam.
    final sides = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(sides, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AvatarCircle extends StatelessWidget {
  final String assetPath;
  const _AvatarCircle({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: 150,
      height: 150,
      fit: BoxFit.contain,
      cacheWidth: 450,
      cacheHeight: 450,
    );
  }
}
