class EmailTemplate {
  final int? id;
  final String naam;
  final String onderwerp;
  final String inhoud;
  final DateTime? createdAt;

  const EmailTemplate({
    this.id,
    required this.naam,
    required this.onderwerp,
    required this.inhoud,
    this.createdAt,
  });

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    return EmailTemplate(
      id: json['id'] as int?,
      naam: (json['naam'] as String?) ?? '',
      onderwerp: (json['onderwerp'] as String?) ?? '',
      inhoud: (json['inhoud'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'naam': naam,
        'onderwerp': onderwerp,
        'inhoud': inhoud,
      };

  EmailTemplate copyWith({
    String? naam,
    String? onderwerp,
    String? inhoud,
  }) {
    return EmailTemplate(
      id: id,
      naam: naam ?? this.naam,
      onderwerp: onderwerp ?? this.onderwerp,
      inhoud: inhoud ?? this.inhoud,
      createdAt: createdAt,
    );
  }
}
