import 'package:flutter/material.dart';
import '../../app/app_mode.dart';

/// Hidden Konami-code easter egg.
///
/// Wraps the whole app (via `MaterialApp.builder`). A **passive** [Listener]
/// observes pointer events without ever competing in the gesture arena, so
/// normal interaction (chart pan, pull-to-refresh, sliders, scrolling) is
/// completely unaffected and nothing reveals the easter egg until solved.
///
/// Sequence: swipe ↑ ↑ ↓ ↓ ← → ← → → on-screen console buttons appear → press
/// B, A, START in order → a red HP bar (30 lives) appears at the top and stays.
class KonamiHost extends StatefulWidget {
  final Widget child;
  const KonamiHost({super.key, required this.child});

  @override
  State<KonamiHost> createState() => _KonamiHostState();
}

enum _Dir { up, down, left, right }

enum _Phase { idle, buttons, activated }

class _KonamiHostState extends State<KonamiHost> {
  // ── Tuning ──────────────────────────────────────────────────────────────
  static const double _minSwipePx = 60;    // min travel to count as a swipe
  static const int    _maxSwipeMs = 600;   // must be a quick flick
  static const _target = [
    _Dir.up, _Dir.up, _Dir.down, _Dir.down,
    _Dir.left, _Dir.right, _Dir.left, _Dir.right,
  ];
  static const _buttonOrder = ['B', 'A', 'START'];

  // ── State ───────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.idle;
  final List<_Dir> _swipes = []; // rolling buffer of recent swipe directions
  int _buttonProgress = 0;       // how many of B→A→START pressed correctly

  // Per-pointer drag start (position + time), single-touch only.
  final Map<int, (Offset, DateTime)> _starts = {};

  // ── Passive swipe detection ───────────────────────────────────────────────
  void _onDown(PointerDownEvent e) {
    _starts[e.pointer] = (e.position, DateTime.now());
  }

  void _onUp(PointerUpEvent e) {
    final start = _starts.remove(e.pointer);
    if (start == null || _phase == _Phase.activated) return;

    final delta = e.position - start.$1;
    final dt = DateTime.now().difference(start.$2).inMilliseconds;
    if (dt > _maxSwipeMs) return;          // too slow → not a flick
    if (delta.distance < _minSwipePx) return; // too short → tap/jitter

    final dir = delta.dx.abs() > delta.dy.abs()
        ? (delta.dx > 0 ? _Dir.right : _Dir.left)
        : (delta.dy > 0 ? _Dir.down : _Dir.up);

    _swipes.add(dir);
    if (_swipes.length > _target.length) {
      _swipes.removeAt(0);
    }
    if (_phase == _Phase.idle && _matchesTarget()) {
      setState(() {
        _phase = _Phase.buttons;
        _buttonProgress = 0;
        _swipes.clear();
      });
    }
  }

  bool _matchesTarget() {
    if (_swipes.length < _target.length) return false;
    for (int i = 0; i < _target.length; i++) {
      if (_swipes[i] != _target[i]) return false;
    }
    return true;
  }

  // ── Console button presses (B → A → START) ────────────────────────────────
  void _press(String label) {
    if (label == _buttonOrder[_buttonProgress]) {
      _buttonProgress++;
      if (_buttonProgress >= _buttonOrder.length) {
        // Unlock: show HP bar + switch the whole app into retro pixel mode.
        pixelModeEnabled.value = true;
        setState(() => _phase = _Phase.activated);
      } else {
        setState(() {}); // advance progress indicator
      }
    } else {
      // Wrong order → hide the buttons; the swipe sequence must be redone.
      setState(() {
        _phase = _Phase.idle;
        _buttonProgress = 0;
        _swipes.clear();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild, // never steal events from children
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: (e) => _starts.remove(e.pointer),
      // HP bar + scanlines are driven by the global flag (not local _phase) so
      // they survive the MaterialApp rebuild that the theme swap triggers.
      child: ValueListenableBuilder<bool>(
        valueListenable: pixelModeEnabled,
        builder: (context, pixelOn, _) {
          return Stack(
            children: [
              widget.child,
              if (pixelOn)
                const Positioned.fill(
                    child: IgnorePointer(child: _Scanlines())),
              if (_phase == _Phase.buttons)
                _ConsolePad(progress: _buttonProgress, onPress: _press),
            ],
          );
        },
      ),
    );
  }
}

// ── CRT scanline overlay ─────────────────────────────────────────────────────

class _Scanlines extends StatelessWidget {
  const _Scanlines();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ScanlinePainter(), size: Size.infinite);
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(28)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Console pad (B / A / START) ──────────────────────────────────────────────

class _ConsolePad extends StatelessWidget {
  final int progress; // 0..3 — how many buttons pressed correctly so far
  final void Function(String) onPress;

  const _ConsolePad({required this.progress, required this.onPress});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(200),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StartButton(
                done: progress > 2,
                onTap: () => onPress('START'),
              ),
              _RoundButton(
                label: 'B',
                color: Colors.red.shade600,
                done: progress > 0,
                onTap: () => onPress('B'),
              ),
              _RoundButton(
                label: 'A',
                color: Colors.green.shade600,
                done: progress > 1,
                onTap: () => onPress('A'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool done;
  final VoidCallback onTap;

  const _RoundButton({
    required this.label,
    required this.color,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
              color: done ? Colors.white : Colors.white24, width: 3),
          boxShadow: [
            BoxShadow(color: color.withAlpha(120), blurRadius: 8),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;

  const _StartButton({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: done ? Colors.white : Colors.white24, width: 3),
        ),
        child: const Text(
          'START',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
