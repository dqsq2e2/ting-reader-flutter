import '../models/models.dart';

int compareChapterOrder(
  bool leftIsExtra,
  int leftIndex,
  String leftId,
  bool rightIsExtra,
  int rightIndex,
  String rightId,
) {
  final typeDifference = (leftIsExtra ? 1 : 0).compareTo(rightIsExtra ? 1 : 0);
  if (typeDifference != 0) return typeDifference;

  final indexDifference = leftIndex.compareTo(rightIndex);
  if (indexDifference != 0) return indexDifference;

  return leftId.compareTo(rightId);
}

int compareChaptersForPlayback(Chapter left, Chapter right) {
  return compareChapterOrder(
    left.isExtra,
    left.chapterIndex,
    left.id,
    right.isExtra,
    right.chapterIndex,
    right.id,
  );
}

List<Chapter> sortChaptersForPlayback(Iterable<Chapter> chapters) {
  return chapters.toList()..sort(compareChaptersForPlayback);
}
