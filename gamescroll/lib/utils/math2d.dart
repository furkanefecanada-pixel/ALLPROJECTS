import 'dart:math';

double clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);

class Vec2 {
  double x;
  double y;
  Vec2(this.x, this.y);

  Vec2 copy() => Vec2(x, y);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  double get len => sqrt(x * x + y * y);

  Vec2 normalized() {
    final l = len;
    if (l < 1e-6) return Vec2(0, 0);
    return Vec2(x / l, y / l);
  }
}
