/// This class is a dataclass for holding the metadata of a particular manga.
class MangaMetaData {
  // Basic Metadata
  final String? title;
  final String? author;
  final bool? nsfw;

  // Extended Metadata
  final String? description;
  final String? bookType;
  final String? titleJp;
  final List<String>? tags;
  final String? artist;
  final String? yearStart;
  final String? yearEnd;
  final String? publisher;
  final String? magazine;
  final bool? englishLicense;
  final bool? visitedMangaUpdates;
  final DateTime? dateAdded;

  MangaMetaData({
    this.title,
    this.author,
    this.nsfw,
    this.description,
    this.bookType,
    this.titleJp,
    this.tags,
    this.artist,
    this.yearStart,
    this.yearEnd,
    this.publisher,
    this.magazine,
    this.englishLicense,
    this.visitedMangaUpdates,
    this.dateAdded,
  });

  factory MangaMetaData.fromJson(Map<String, dynamic> json) {
    final dynamic tags = json['tags'];
    final dynamic dateAdded = json['dateAdded'];

    return MangaMetaData(
      title: json['title'],
      author: json['author'],
      nsfw: json['nsfw'],
      description: json['description'],
      bookType: json['booktype'],
      titleJp: json['title-jp'],
      tags:
          (tags != null && tags is List<dynamic>) ? tags.cast<String>() : null,
      artist: json['artist'],
      yearStart: json['yearstart'],
      yearEnd: json['yearend'],
      publisher: json['publisher'],
      magazine: json['magazine'],
      englishLicense: json['englishlicense'],
      visitedMangaUpdates: json['visited_mangaupdates'],
      dateAdded: (dateAdded != null) ? DateTime.parse(dateAdded) : null,
    );
  }

  /// Checks if the required fields for a manga thumbnail are present.
  /// Returns true if all required fields are present.
  bool checkRequiredFieldsThumbnail() {
    return title != null && author != null && nsfw != null;
  }

  /// Checks if the required fields for a manga info page are present.
  /// Returns true if all required fields are present.
  bool checkRequiredFieldsInfoPage() {
    return title != null &&
        author != null &&
        artist != null &&
        description != null &&
        yearStart != null;
  }
}
