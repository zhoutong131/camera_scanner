import 'package:flutter/material.dart';

class ScanOverlay extends LeafRenderObjectWidget {

  const ScanOverlay({ required this.imgWidth,super.key,this.rate = 0.25});

  final double imgWidth;

  final double rate;

  @override
  RenderObject createRenderObject(BuildContext context) {
    // TODO: implement createRenderObject
    return OverLayView(imgWidth: imgWidth,rate: rate);
  }
}

class OverLayView extends RenderBox {

  OverLayView({ required this.imgWidth,required this.rate});

  final double imgWidth;

  final double rate;

  @override
  void performLayout() {
    // TODO: implement performLayout
    size = constraints.constrain(Size.infinite);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO: implement paint
    // 除了矩形外都是 mask
    Rect outerRect = offset & size;
    double xWidth = (imgWidth*rate)/(imgWidth/size.width);
    var path1 = Path();
    path1.addRect(outerRect);
    // 画中间的矩形，宽600，高600// 线粗
    Rect rect2 = Rect.fromLTWH(offset.dx+(size.width - xWidth)/2, offset.dy+(size.height - xWidth) / 2, xWidth, xWidth);
    var path2 = Path();
    path2.addRect(rect2);

    var linePaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
    ..strokeWidth = 8.0;
    Path path = Path.combine(PathOperation.xor, path1, path2);
    var backPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.35)
    ..style = PaintingStyle.fill;
    context.canvas.drawPath(path, backPaint);
    // 左上角
    context.canvas.drawLine(rect2.topLeft, Offset(rect2.left + 40,rect2.top), linePaint);
    context.canvas.drawLine(rect2.topLeft, Offset(rect2.left, rect2.top + 40), linePaint);
    // 右上角
    context.canvas.drawLine(Offset(rect2.right - 40, rect2.top), rect2.topRight, linePaint);
    context.canvas.drawLine(Offset(rect2.right, rect2.top + 40), rect2.topRight, linePaint);
    // 左下角
    context.canvas.drawLine(rect2.bottomLeft, Offset(rect2.left,rect2.bottom-40), linePaint);
    context.canvas.drawLine(rect2.bottomLeft, Offset(rect2.left+40, rect2.bottom), linePaint);
    // 右下角
    context.canvas.drawLine(rect2.bottomRight, Offset(rect2.right,rect2.bottom-40), linePaint);
    context.canvas.drawLine(rect2.bottomRight, Offset(rect2.right-40, rect2.bottom), linePaint);
  }
}