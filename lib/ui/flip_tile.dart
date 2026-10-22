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
              borderRadius: BorderRadius.circular(5),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x70000000),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
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
                        top: height / 2 - .45,
                        child: Container(
                          height: .9,
                          color: const Color(0x60000000),
                        ),
                      ),
                      for (final bool left in <bool>[true, false])
                        Positioned(
                          left: left ? 0 : null,
                          right: left ? null : 0,
                          top: height / 2 - 3.5,
                          child: Container(
                            width: 2.5,
                            height: 7,
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

/// 瘦长、等宽数字配合压薄的折缝；上下半页共用同一牌面，翻转时基线保持一致。
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
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFEFF1ED), width: .8),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFF7F8F4),
          Color(0xFFDDE1DB),
          Color(0xFFFAFBF7),
          Color(0xFFE8ECE7),
        ],
        stops: <double>[0, .498, .502, 1],
      ),
    ),
    alignment: Alignment.center,
    child: SizedBox(
      width: width * .85,
      height: height * .86,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Text(
          value,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Helvetica Neue',
            fontFamilyFallback: const <String>['Arial'],
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            fontSize: height,
            fontWeight: FontWeight.w400,
            height: .78,
            leadingDistribution: TextLeadingDistribution.even,
            decoration: TextDecoration.none,
            letterSpacing: -height * .035,
            color: const Color(0xFF232627),
            shadows: const <Shadow>[
              Shadow(color: Color(0xA0FFFFFF), offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    ),
  );
}
