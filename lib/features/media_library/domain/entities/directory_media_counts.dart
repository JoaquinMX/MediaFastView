/// Aggregate media counts for a directory derived from cached media records.
class DirectoryMediaCounts {
  const DirectoryMediaCounts({
    this.totalMediaCount = 0,
    this.taggedMediaCount = 0,
  });

  final int totalMediaCount;
  final int taggedMediaCount;
}
