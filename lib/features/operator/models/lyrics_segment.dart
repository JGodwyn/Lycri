enum LyricsSegmentType { intro, verse, preChorus, chorus, bridge, outro }

class LyricsSegment {
  final String id;
  final String text;
  final LyricsSegmentType type;
  final int number;

  const LyricsSegment({
    required this.id,
    required this.text,
    required this.type,
    required this.number,
  });

  LyricsSegment copyWith({
    String? id,
    String? text,
    LyricsSegmentType? type,
    int? number,
  }) {
    return LyricsSegment(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      number: number ?? this.number,
    );
  }

  /// Calculates the number of non-empty lines in this segment.
  int get lineCount =>
      text.split('\n').where((l) => l.trim().isNotEmpty).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsSegment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          type == other.type &&
          number == other.number;

  @override
  int get hashCode =>
      id.hashCode ^ text.hashCode ^ type.hashCode ^ number.hashCode;
}

class SegmentedLyricsState {
  final List<LyricsSegment> segments;
  final bool isSegmented;
  final bool isLoading;

  const SegmentedLyricsState({
    required this.segments,
    required this.isSegmented,
    this.isLoading = false,
  });

  factory SegmentedLyricsState.initial() => const SegmentedLyricsState(
    segments: [],
    isSegmented: false,
    isLoading: false,
  );

  SegmentedLyricsState copyWith({
    List<LyricsSegment>? segments,
    bool? isSegmented,
    bool? isLoading,
  }) {
    return SegmentedLyricsState(
      segments: segments ?? this.segments,
      isSegmented: isSegmented ?? this.isSegmented,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
