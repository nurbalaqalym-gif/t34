import 'package:flutter/material.dart';

void main() => runApp(const DrawApp());

// Один мазок: цвет, толщина и все точки, через которые прошёл палец
class Stroke {
  Stroke(this.color, this.width);

  final Color color;
  final double width;
  final List<Offset> points = [];
}

const Color kPaper = Colors.white;

const List<Color> kPalette = [
  Colors.black,
  Colors.red,
  Colors.orange,
  Colors.amber,
  Colors.green,
  Colors.blue,
  Colors.purple,
  Colors.brown,
];

class DrawApp extends StatelessWidget {
  const DrawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Рисовалка',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.pink,
      ),
      home: const DrawPage(),
    );
  }
}

class DrawPage extends StatefulWidget {
  const DrawPage({super.key});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final List<Stroke> _strokes = [];
  final List<Stroke> _redo = []; // отменённые мазки, чтобы можно было вернуть

  Color _color = Colors.black;
  double _width = 6;
  bool _eraser = false;

  int? _pointer; // какой палец сейчас рисует (остальные игнорируем)
  Stroke? _current;

  void _onDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;

    // Ластик: просто рисуем цветом бумаги, и потолще
    final stroke = Stroke(
      _eraser ? kPaper : _color,
      _eraser ? _width * 2 : _width,
    )..points.add(e.localPosition);

    setState(() {
      _strokes.add(stroke);
      _current = stroke;
      _redo.clear(); // новый мазок: "вернуть" больше нельзя
    });
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    setState(() => _current?.points.add(e.localPosition));
  }

  void _onUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _current = null;
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redo.add(_strokes.removeLast()));
  }

  void _redoStroke() {
    if (_redo.isEmpty) return;
    setState(() => _strokes.add(_redo.removeLast()));
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить рисунок?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _strokes.clear();
      _redo.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рисовалка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Отменить',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Вернуть',
            onPressed: _redo.isEmpty ? null : _redoStroke,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Очистить',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Холст
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  // Listener даёт самые "сырые" касания: рисование начинается мгновенно
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onDown,
                    onPointerMove: _onMove,
                    onPointerUp: _onUp,
                    onPointerCancel: _onUp,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: CanvasPainter(_strokes),
                    ),
                  ),
                ),
              ),
            ),
            // Панель инструментов
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final c in kPalette)
                        GestureDetector(
                          onTap: () => setState(() {
                            _color = c;
                            _eraser = false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (_color == c && !_eraser)
                                    ? cs.primary
                                    : cs.outlineVariant,
                                width: (_color == c && !_eraser) ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Предпросмотр кисти
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Container(
                            width: _width,
                            height: _width,
                            decoration: BoxDecoration(
                              color: _eraser ? cs.outline : _color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _width,
                          min: 2,
                          max: 30,
                          onChanged: (v) => setState(() => _width = v),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Ластик'),
                        selected: _eraser,
                        onSelected: (v) => setState(() => _eraser = v),
                      ),
                    ],
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

// Рисует белую бумагу и все мазки поверх неё
class CanvasPainter extends CustomPainter {
  CanvasPainter(this.strokes);

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kPaper);

    for (final s in strokes) {
      final p = s.points;

      // Одно касание без движения: рисуем точку
      if (p.length == 1) {
        canvas.drawCircle(p.first, s.width / 2, Paint()..color = s.color);
        continue;
      }

      // Линия через середины отрезков: получается плавная кривая, а не ломаная
      final path = Path()..moveTo(p.first.dx, p.first.dy);
      for (var i = 1; i < p.length; i++) {
        final mid = Offset(
          (p[i - 1].dx + p[i].dx) / 2,
          (p[i - 1].dy + p[i].dy) / 2,
        );
        path.quadraticBezierTo(p[i - 1].dx, p[i - 1].dy, mid.dx, mid.dy);
      }
      path.lineTo(p.last.dx, p.last.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..strokeWidth = s.width
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  // Список мазков меняется "на месте", поэтому перерисовываем всегда
  @override
  bool shouldRepaint(CanvasPainter old) => true;
}
