import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 单块翻页牌：先收起旧数字上半页，再落下新数字下半页；只在数值变化时启动。
/// 时与分各占一块，跨小时两块同时翻；减少动态效果时直接切换为最终数字。
class FlipTile extends StatefulWidget {
  const FlipTile({required this.value, super.key});
  final String value;
  @override
  State<FlipTile> createState() => _FlipTileState();
}

class _FlipTileState extends State<FlipTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );
  late String _old = widget.value;
  @override
  void didUpdateWidget(covariant FlipTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _old = oldWidget.value;
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.value,
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints bounds) {
          final double width = bounds.maxWidth, height = bounds.maxHeight;
          Widget half(String value, bool top) => ClipRect(
            child: SizedBox(
              width: width,
              height: height / 2,
              child: OverflowBox(
                alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
                minHeight: height,
                maxHeight: height,
                child: _TileFace(value: value, width: width, height: height),
              ),
            ),
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xAA000000),
                  blurRadius: 9,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (BuildContext context, Widget? child) {
                  final double t = _animation.isAnimating
                      ? _animation.value
                      : 1;
                  return Stack(
                    children: <Widget>[
                      Positioned(top: 0, child: half(widget.value, true)),
                      Positioned(
                        bottom: 0,
                        child: half(t < 1 ? _old : widget.value, false),
                      ),
                      if (t < .5)
                        Positioned(
                          top: 0,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .003)
                              ..rotateX(
                                -math.pi / 2 * Curves.easeIn.transform(t * 2),
                              ),
                            child: half(_old, true),
                          ),
                        ),
                      if (t >= .5 && t < 1)
                        Positioned(
                          bottom: 0,
                          child: Transform(
                            alignment: Alignment.topCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .003)
                              ..rotateX(
                                math.pi /
                                    2 *
                                    (1 -
                                        Curves.easeOutCubic.transform(
                                          (t - .5) * 2,
                                        )),
                              ),
                            child: half(widget.value, false),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: height / 2 - 1,
                        child: Container(
                          height: 2,
                          color: const Color(0x90000000),
                        ),
                      ),
                      for (final bool left in <bool>[true, false])
                        Positioned(
                          left: left ? 0 : null,
                          right: left ? null : 0,
                          top: height / 2 - 5,
                          child: Container(
                            width: 5,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF777777),
                                  Color(0xFF252525),
                                  Color(0xFFAAAAAA),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// 完整牌面的渐变与数字由上下两个裁切面共用，翻转过程中保持同一字号与基线。
class _TileFace extends StatelessWidget {
  const _TileFace({
    required this.value,
    required this.width,
    required this.height,
  });
  final String value;
  final double width, height;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFF4F3EF),
          Color(0xFFDEDED9),
          Color(0xFFFBFBF8),
          Color(0xFFEAE9E4),
        ],
        stops: <double>[0, .49, .51, 1],
      ),
    ),
    alignment: Alignment.center,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          value,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Helvetica Neue',
            fontFamilyFallback: const <String>['Arial'],
            fontSize: height * .80,
            fontWeight: FontWeight.w700,
            height: 1.10,
            letterSpacing: -height * .06,
            color: const Color(0xFF161719),
            shadows: const <Shadow>[
              Shadow(color: Colors.white, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    ),
  );
}
