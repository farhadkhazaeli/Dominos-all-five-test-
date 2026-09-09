class DominoTile {
  final int a;
  final int b;

  const DominoTile(this.a, this.b);

  bool get isDouble => a == b;
  int get pipSum => a + b;

  bool matches(int value) => a == value || b == value;

  int otherSide(int value) {
    if (a == value) return b;
    if (b == value) return a;
    throw ArgumentError('Tile $this does not match $value');
  }

  @override
  String toString() => '[$a|$b]';

  @override
  bool operator ==(Object other) =>
      other is DominoTile &&
      ((a == other.a && b == other.b) ||
       (a == other.b && b == other.a));

  @override
  int get hashCode => Object.hash(a < b ? a : b, a < b ? b : a);
}
