import 'domino_tile.dart';

int scoreOpenEnds(int left, int right, {required bool isOpeningMove}) {
  if (isOpeningMove) return 0;
  final total = left + right;
  if (total > 0 && total % 5 == 0) return total;
  return 0;
}

int floorToFive(int value) => value - (value % 5);

int handPipTotal(List<DominoTile> hand) =>
    hand.fold(0, (sum, tile) => sum + tile.pipSum);

int roundEndAwardFromLosingHand(List<DominoTile> losingHand) {
  if (losingHand.length == 1 && losingHand.first.a == 0 && losingHand.first.b == 0) {
    return 10;
  }
  return floorToFive(handPipTotal(losingHand));
}
