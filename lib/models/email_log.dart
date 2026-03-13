enum EmailStatus {
  concept('Concept'),
  gepland('Gepland'),
  verzonden('Verzonden'),
  mislukt('Mislukt'),
  gearchiveerd('Gearchiveerd'),
  conversie('Conversie');

  final String label;
  const EmailStatus(this.label);

  static EmailStatus fromString(String? value) {
    if (value == null) return EmailStatus.verzonden;
    return EmailStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => EmailStatus.verzonden,
    );
  }

  bool get isEditable => this == concept || this == mislukt;
  bool get canResend => this == concept || this == mislukt || this == gepland;
}

class EmailLog {
  final int? id;
  final int leadId;
  final String leadNaam;
  final String? templateNaam;
  final String? kortingscode;
  final String? producten;
  final String verzondenAan;
  final String verzondenVia;
  final DateTime? verzondenOp;
  final EmailStatus status;
  final String? onderwerp;
  final String? inhoud;
  final String? foutmelding;

  const EmailLog({
    this.id,
    required this.leadId,
    required this.leadNaam,
    this.templateNaam,
    this.kortingscode,
    this.producten,
    required this.verzondenAan,
    this.verzondenVia = 'smtp',
    this.verzondenOp,
    this.status = EmailStatus.verzonden,
    this.onderwerp,
    this.inhoud,
    this.foutmelding,
  });

  factory EmailLog.fromJson(Map<String, dynamic> json) {
    final via = (json['verzonden_via'] as String?) ?? 'smtp';
    return EmailLog(
      id: json['id'] as int?,
      leadId: json['lead_id'] as int,
      leadNaam: (json['lead_naam'] as String?) ?? '',
      templateNaam: json['template_naam'] as String?,
      kortingscode: json['kortingscode'] as String?,
      producten: json['producten'] as String?,
      verzondenAan: (json['verzonden_aan'] as String?) ?? '',
      verzondenVia: via,
      verzondenOp: json['verzonden_op'] != null
          ? DateTime.tryParse(json['verzonden_op'] as String)
          : null,
      status: via == 'conversie'
          ? EmailStatus.conversie
          : EmailStatus.fromString(json['status'] as String?),
      onderwerp: json['onderwerp'] as String?,
      inhoud: json['inhoud'] as String?,
      foutmelding: json['foutmelding'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'lead_id': leadId,
        'lead_naam': leadNaam,
        'template_naam': templateNaam,
        'kortingscode': kortingscode,
        'producten': producten,
        'verzonden_aan': verzondenAan,
        'verzonden_via': verzondenVia,
        'status': status.name,
        if (onderwerp != null) 'onderwerp': onderwerp,
        if (inhoud != null) 'inhoud': inhoud,
        if (foutmelding != null) 'foutmelding': foutmelding,
      };

  EmailLog copyWith({
    int? id,
    int? leadId,
    String? leadNaam,
    String? templateNaam,
    String? kortingscode,
    String? producten,
    String? verzondenAan,
    String? verzondenVia,
    DateTime? verzondenOp,
    EmailStatus? status,
    String? onderwerp,
    String? inhoud,
    String? foutmelding,
  }) {
    return EmailLog(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      leadNaam: leadNaam ?? this.leadNaam,
      templateNaam: templateNaam ?? this.templateNaam,
      kortingscode: kortingscode ?? this.kortingscode,
      producten: producten ?? this.producten,
      verzondenAan: verzondenAan ?? this.verzondenAan,
      verzondenVia: verzondenVia ?? this.verzondenVia,
      verzondenOp: verzondenOp ?? this.verzondenOp,
      status: status ?? this.status,
      onderwerp: onderwerp ?? this.onderwerp,
      inhoud: inhoud ?? this.inhoud,
      foutmelding: foutmelding ?? this.foutmelding,
    );
  }
}
