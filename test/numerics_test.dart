import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:xirr/src/numerics.dart';

void main() {
  test('log1p and expm1 are accurate for tiny values', () {
    expect(log1p(1e-20), 1e-20);
    expect(log1p(0), 0);
    expect(log1p(1), closeTo(math.ln2, 1e-15));
    expect(log1p(-0.5), closeTo(-math.ln2, 1e-15));
    expect(expm1(1e-20), 1e-20);
    expect(expm1(0), 0);
    expect(expm1(1), closeTo(math.e - 1, 1e-15));
    expect(expm1(-800), -1);
    expect(expm1(1000), double.infinity);
  });

  test('log1p and expm1 are inverses', () {
    for (final r in [-0.99, -0.5, -1e-9, 1e-9, 0.1, 10.0, 1e6]) {
      expect(expm1(log1p(r)), closeTo(r, r.abs() * 1e-13 + 1e-18),
          reason: '$r');
    }
  });

  group('solvers on a hand-made series', () {
    // f(x) = -1 + 2 * exp(-x): root x = ln 2
    final series = Series([0.0, 1.0], [-1.0, 2.0]);
    const root = math.ln2;

    test('newton', () {
      final o = newton(series, 0.5, -20, 20, 1e-12, 50);
      expect(o.converged, isTrue);
      expect(o.x, closeTo(root, 1e-10));
    });

    test('newton: exact zero at the start converges in one step', () {
      final s = Series([0.0, 1.0], [-1.0, 1.0]); // root at x = 0
      final o = newton(s, 0, -20, 20, 1e-12, 50);
      expect(o.converged, isTrue);
      expect(o.iterations, 1);
    });

    test('newton: zero slope fails', () {
      final s = Series([0.0, 1.0, 2.0], [-3.0, 2.0, -1.0]);
      // derivative at x = 0 is -(2*1 - 1*2) = 0
      final o = newton(s, 0, -20, 20, 1e-12, 50);
      expect(o.converged, isFalse);
    });

    test('newton: huge step is clamped, leaving bounds fails cleanly', () {
      final s = Series([0.0, 0.001], [-1.0, 2.0]); // root at x ~ 693
      final o = newton(s, 0, -20, 20, 1e-12, 50);
      expect(o.converged, isFalse);
    });

    test('newton: iteration limit', () {
      final o = newton(series, 0.5, -20, 20, 1e-300, 3);
      expect(o.converged, isFalse);
      expect(o.iterations, 3);
    });

    test('bracket + brent + bisection', () {
      final br = findBracket(series, 0.0, -20, 20)!;
      expect(br.fLo * br.fHi, lessThan(0));
      expect(brent(series, br, 1e-12, 100).x, closeTo(root, 1e-10));
      expect(bisection(series, br, 1e-12, 200).x, closeTo(root, 1e-10));
    });

    test('bracket search from either side and at the bounds', () {
      expect(findBracket(series, 15, -20, 20), isNotNull);
      expect(findBracket(series, -15, -20, 20), isNotNull);
      expect(
          findBracket(series, 100, -20, 20), isNotNull); // clamped into range
      expect(findBracket(series, 0, 5, 20), isNull); // no root in [5, 20]
      expect(findBracket(series, 0, -20, -5), isNull);
    });

    test('bracket: a start that is exactly a root', () {
      final s = Series([0.0, 1.0], [-1.0, 1.0]);
      final br = findBracket(s, 0, -20, 20)!;
      expect(br.lo, br.hi);
      expect(brent(s, br, 1e-12, 10).iterations, 0);
      expect(bisection(s, br, 1e-12, 10).iterations, 0);
    });

    test('bracket: a root met exactly while walking outwards', () {
      // root at x = 0.05 (the first step to the right)
      final s = Series([0.0, 1.0], [-1.0, math.exp(0.05)]);
      final br = findBracket(s, 0, -20, 20)!;
      expect(br.lo, br.hi);
    });

    test('bracket: NaN values give up', () {
      final s = Series([0.0, 1.0], [double.nan, 1.0]);
      expect(findBracket(s, 0, -20, 20), isNull);
    });

    test('iteration limits on bracketing solvers', () {
      final br = findBracket(series, 0.0, -20, 20)!;
      expect(brent(series, br, 1e-300, 1).converged, isFalse);
      expect(bisection(series, br, 1e-300, 2).converged, isFalse);
    });

    test('relative residual and npv', () {
      expect(series.relativeResidual(root), lessThan(1e-12));
      expect(series.relativeResidual(5), greaterThan(0.5));
      expect(Series([0.0], [0.0]).relativeResidual(0), double.infinity);
      expect(series.npv(root).abs(), lessThan(1e-12));
      expect(series.length, 2);
    });
  });
}
