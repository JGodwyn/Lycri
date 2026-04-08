enum LyricsSegmentType { intro, verse, preChorus, chorus, bridge, outro }

class LyricsSegment {
  final String id;
  final String text;
  final LyricsSegmentType type;
  final int number;
  final bool isHidden;

  const LyricsSegment({
    required this.id,
    required this.text,
    required this.type,
    required this.number,
    this.isHidden = false,
  });

  LyricsSegment copyWith({
    String? id,
    String? text,
    LyricsSegmentType? type,
    int? number,
    bool? isHidden,
  }) {
    return LyricsSegment(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      number: number ?? this.number,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'type': type.name,
      'number': number,
      'isHidden': isHidden,
    };
  }

  factory LyricsSegment.fromJson(Map<String, dynamic> json) {
    return LyricsSegment(
      id: json['id'] as String,
      text: json['text'] as String,
      type: LyricsSegmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LyricsSegmentType.verse, // fallback
      ),
      number: json['number'] as int,
      isHidden: json['isHidden'] as bool? ?? false,
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
          number == other.number &&
          isHidden == other.isHidden;

  @override
  int get hashCode =>
      id.hashCode ^
      text.hashCode ^
      type.hashCode ^
      number.hashCode ^
      isHidden.hashCode;
}

class SegmentedLyricsState {
  final List<LyricsSegment> segments;
  final bool isSegmented;
  final bool isLoading;
  final String? songTitle;
  final bool isSaved;
  final String? songId;
  final bool isEditing;
  final List<LyricsSegment>? originalSegments;

  const SegmentedLyricsState({
    required this.segments,
    required this.isSegmented,
    this.isLoading = false,
    this.songTitle,
    this.isSaved = false,
    this.songId,
    this.isEditing = false,
    this.originalSegments,
  });

  factory SegmentedLyricsState.initial() => const SegmentedLyricsState(
        segments: [],
        isSegmented: false,
        isLoading: false,
        songTitle: null,
        isSaved: false,
        songId: null,
        isEditing: false,
        originalSegments: null,
      );

  bool get hasChanges {
    if (originalSegments == null) return false;
    // We ignore isHidden when comparing for changes.
    // Length check first.
    if (segments.length != originalSegments!.length) return true;

    for (int i = 0; i < segments.length; i++) {
      final a = segments[i];
      final b = originalSegments![i];
      if (a.text != b.text || a.type != b.type || a.number != b.number) {
        return true;
      }
    }
    return false;
  }

  SegmentedLyricsState copyWith({
    List<LyricsSegment>? segments,
    bool? isSegmented,
    bool? isLoading,
    String? songTitle,
    bool? isSaved,
    String? songId,
    bool? isEditing,
    List<LyricsSegment>? originalSegments,
  }) {
    return SegmentedLyricsState(
      segments: segments ?? this.segments,
      isSegmented: isSegmented ?? this.isSegmented,
      isLoading: isLoading ?? this.isLoading,
      songTitle: songTitle ?? this.songTitle,
      isSaved: isSaved ?? this.isSaved,
      songId: songId ?? this.songId,
      isEditing: isEditing ?? this.isEditing,
      originalSegments: originalSegments ?? this.originalSegments,
    );
  }
}
