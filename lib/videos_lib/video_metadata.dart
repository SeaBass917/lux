/// This class is a dataclass for holding the metadata of a particular video.
class VideoMetaData {
  final String? title;
  final bool? nsfw;
  final String? description;
  final String? studio;
  final String? staff;
  final String? yearStart;
  final String? yearEnd;
  final String? producer;
  final bool? englishLicense;
  final String? director;
  final List<String>? tags;
  final bool? visitedIMDB;
  final bool? visitedWikipedia;
  final bool? visitedMal;
  final DateTime? dateAdded;

  VideoMetaData({
    this.title,
    this.nsfw,
    this.studio,
    this.staff,
    this.yearStart,
    this.yearEnd,
    this.producer,
    this.englishLicense,
    this.visitedMal,
    this.director,
    this.tags,
    this.visitedIMDB,
    this.visitedWikipedia,
    this.dateAdded,
    this.description,
  });

  factory VideoMetaData.fromJson(Map<String, dynamic> json) {
    final dynamic tags = json['tags'];
    final dynamic dateAdded = json['dateAdded'];

    return VideoMetaData(
      title: json["title"],
      nsfw: json["nsfw"],
      description: json["description"],
      studio: json["studio"],
      staff: json["staff"],
      yearStart: json["yearstart"],
      yearEnd: json["yearend"],
      producer: json["producer"],
      englishLicense: json["english_license"],
      visitedMal: json["visited_mal"],
      director: json["director"],
      tags:
          (tags != null && tags is List<dynamic>) ? tags.cast<String>() : null,
      visitedIMDB: json["visited_imdb"],
      visitedWikipedia: json["visited_wikipedia"],
      dateAdded: (dateAdded != null) ? DateTime.parse(dateAdded) : null,
    );
  }

  /// Checks if the required fields for a thumbnail are present.
  /// Returns true if all required fields are present.
  bool checkRequiredFieldsThumbnail() {
    return title != null && nsfw != null;
  }

  /// Checks if the required fields for a info page are present.
  /// Returns true if all required fields are present.
  bool checkRequiredFieldsInfoPage() {
    return title != null &&
        description != null &&
        tags != null &&
        yearStart != null;
  }
}
