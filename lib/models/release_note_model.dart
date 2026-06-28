import 'package:cloud_firestore/cloud_firestore.dart';

class ReleaseNote {
  final String version;
  final DateTime date;
  final String title;
  final List<String> notes;
  final bool isCritical;

  ReleaseNote({
    required this.version,
    required this.date,
    required this.title,
    required this.notes,
    this.isCritical = false,
  });

  factory ReleaseNote.fromMap(Map<String, dynamic> map) {
    return ReleaseNote(
      version: map['version'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: map['title'] as String? ?? '',
      notes: List<String>.from(map['notes'] as Iterable? ?? []),
      isCritical: map['isCritical'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'date': Timestamp.fromDate(date),
      'title': title,
      'notes': notes,
      'isCritical': isCritical,
    };
  }
}
