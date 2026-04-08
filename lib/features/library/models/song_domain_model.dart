import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';

/// The domain model for a Song, decoupled from the underlying database implementation.
class SongDomainModel {
  final String id;
  final String title;
  final String originalText;
  final String? artist;
  final List<LyricsSegment> segments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SongDomainModel({
    required this.id,
    required this.title,
    required this.originalText,
    this.artist,
    required this.segments,
    required this.createdAt,
    required this.updatedAt,
  });

  SongDomainModel copyWith({
    String? id,
    String? title,
    String? originalText,
    String? artist,
    List<LyricsSegment>? segments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SongDomainModel(
      id: id ?? this.id,
      title: title ?? this.title,
      originalText: originalText ?? this.originalText,
      artist: artist ?? this.artist,
      segments: segments ?? this.segments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'originalText': originalText,
      'artist': artist,
      'segments': segments.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SongDomainModel.fromJson(Map<String, dynamic> json) {
    return SongDomainModel(
      id: json['id'] as String,
      title: json['title'] as String,
      originalText: json['originalText'] as String,
      artist: json['artist'] as String?,
      segments: (json['segments'] as List<dynamic>?)
              ?.map((s) => LyricsSegment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongDomainModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          originalText == other.originalText &&
          artist == other.artist &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      originalText.hashCode ^
      artist.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
