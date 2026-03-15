import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Roles ────────────────────────────────────────────────────────────────

enum UserType { owner, admin, wederverkoper, prospect, klant, user }

extension UserTypeExt on UserType {
  String get dbValue {
    switch (this) {
      case UserType.owner: return 'owner';
      case UserType.admin: return 'admin';
      case UserType.wederverkoper: return 'wederverkoper';
      case UserType.prospect: return 'prospect';
      case UserType.klant: return 'klant';
      case UserType.user: return 'user';
    }
  }

  String get label {
    switch (this) {
      case UserType.owner: return 'Eigenaar';
      case UserType.admin: return 'Beheerder';
      case UserType.wederverkoper: return 'Wederverkoper';
      case UserType.prospect: return 'Prospect';
      case UserType.klant: return 'Klant';
      case UserType.user: return 'Gebruiker';
    }
  }

  static UserType fromDb(String? val) {
    switch (val) {
      case 'owner': return UserType.owner;
      case 'admin': return UserType.admin;
      case 'wederverkoper': return UserType.wederverkoper;
      case 'prospect': return UserType.prospect;
      case 'klant': return UserType.klant;
      case 'user': return UserType.user;
      // Legacy migration
      case 'medewerker': return UserType.admin;
      case 'klant_particulier': return UserType.klant;
      case 'klant_organisatie': return UserType.klant;
      case 'generiek': return UserType.user;
      default: return UserType.user;
    }
  }

  bool get mfaRequired {
    switch (this) {
      case UserType.owner: return true;
      case UserType.admin: return true;
      case UserType.wederverkoper: return true;
      case UserType.prospect: return false;
      case UserType.klant: return false;
      case UserType.user: return false;
    }
  }

  bool get mfaOptional {
    switch (this) {
      case UserType.klant: return true;
      default: return false;
    }
  }

  bool get hasLeadAccess {
    switch (this) {
      case UserType.owner: return true;
      case UserType.admin: return true;
      default: return false;
    }
  }

  bool get hasDashboardAccess {
    switch (this) {
      case UserType.owner: return true;
      case UserType.admin: return true;
      case UserType.wederverkoper: return true;
      case UserType.klant: return true;
      default: return false;
    }
  }

  bool get requiresBtw {
    switch (this) {
      case UserType.wederverkoper: return true;
      default: return false;
    }
  }

  bool get isBedrijf {
    switch (this) {
      case UserType.wederverkoper: return true;
      default: return false;
    }
  }
}

// ─── Permissions ──────────────────────────────────────────────────────────

class UserPermissions {
  // Catalogus & Producten
  final bool productenBewerken;
  final bool uitgelichteProducten;
  final bool productenBlokkeren;

  // Orders & Bestellingen
  final bool eigenBestelhistorie;
  final bool bezorgstatusVolgen;
  final bool alleBestellingenBeheren;
  final bool bestellingenVerzenden;

  // Leads & Marketing
  final bool leadsInzien;
  final bool leadsWijzigen;
  final bool leadEmailsVersturen;
  final bool leadsVerwijderen;
  final bool leadsExporteren;
  final bool statistiekenBekijken;
  final bool kortingscodesBeheren;

  // E-mail & Communicatie
  final bool emailTemplatesBeheren;
  final bool smtpInstellingen;
  final bool orderTemplatesBewerken;

  // Website & Content
  final bool aboutTekstBewerken;
  final bool impressiesBeheren;
  final bool categoryVideosBeheren;
  final bool reviewPlatformsBeheren;

  // Verzending & Voorraad
  final bool zendingenOverzicht;
  final bool productgewichtenBeheren;
  final bool verpakkingenBeheren;
  final bool voorraadBeheren;
  final bool voorraadImporteren;
  final bool eanCodesBeheren;
  final bool klantenBeheren;
  final bool verkoopkanalenBeheren;

  // Koppelingen (integraties) -- Owner only
  final bool myparcelInstellingen;
  final bool betaalgatewayInstellingen;
  final bool marktplaatsKoppelingen;

  // Beheer & Beveiliging
  final bool gebruikersBeheren;
  final bool ownersAdminsBeheren;
  final bool rollenRechtenToewijzen;
  final bool bedrijfsgegevensBewerken;
  final bool betaalmethodenOverzicht;
  final bool geblokkeerdeAccountsBeheren;
  final bool activiteitenlogBekijken;
  final bool activiteitenlogWijzigen;
  final bool testmodus;

  // Profiel & Account
  final bool eigenProfielBewerken;
  final bool eigenWachtwoordWijzigen;
  final bool mfaSchakelen;
  final bool puntensaldoBekijken;

  const UserPermissions({
    this.productenBewerken = false,
    this.uitgelichteProducten = false,
    this.productenBlokkeren = false,
    this.eigenBestelhistorie = false,
    this.bezorgstatusVolgen = false,
    this.alleBestellingenBeheren = false,
    this.bestellingenVerzenden = false,
    this.leadsInzien = false,
    this.leadsWijzigen = false,
    this.leadEmailsVersturen = false,
    this.leadsVerwijderen = false,
    this.leadsExporteren = false,
    this.statistiekenBekijken = false,
    this.kortingscodesBeheren = false,
    this.emailTemplatesBeheren = false,
    this.smtpInstellingen = false,
    this.orderTemplatesBewerken = false,
    this.aboutTekstBewerken = false,
    this.impressiesBeheren = false,
    this.categoryVideosBeheren = false,
    this.reviewPlatformsBeheren = false,
    this.zendingenOverzicht = false,
    this.productgewichtenBeheren = false,
    this.verpakkingenBeheren = false,
    this.voorraadBeheren = false,
    this.voorraadImporteren = false,
    this.eanCodesBeheren = false,
    this.klantenBeheren = false,
    this.verkoopkanalenBeheren = false,
    this.myparcelInstellingen = false,
    this.betaalgatewayInstellingen = false,
    this.marktplaatsKoppelingen = false,
    this.gebruikersBeheren = false,
    this.ownersAdminsBeheren = false,
    this.rollenRechtenToewijzen = false,
    this.bedrijfsgegevensBewerken = false,
    this.betaalmethodenOverzicht = false,
    this.geblokkeerdeAccountsBeheren = false,
    this.activiteitenlogBekijken = false,
    this.activiteitenlogWijzigen = false,
    this.testmodus = false,
    this.eigenProfielBewerken = false,
    this.eigenWachtwoordWijzigen = false,
    this.mfaSchakelen = false,
    this.puntensaldoBekijken = false,
  });

  // ── Role presets ──

  static const ownerPreset = UserPermissions(
    productenBewerken: true, uitgelichteProducten: true, productenBlokkeren: true,
    eigenBestelhistorie: true, bezorgstatusVolgen: true, alleBestellingenBeheren: true, bestellingenVerzenden: true,
    leadsInzien: true, leadsWijzigen: true, leadEmailsVersturen: true, leadsVerwijderen: true, leadsExporteren: true, statistiekenBekijken: true, kortingscodesBeheren: true,
    emailTemplatesBeheren: true, smtpInstellingen: true, orderTemplatesBewerken: true,
    aboutTekstBewerken: true, impressiesBeheren: true, categoryVideosBeheren: true, reviewPlatformsBeheren: true,
    zendingenOverzicht: true, productgewichtenBeheren: true, verpakkingenBeheren: true, voorraadBeheren: true, voorraadImporteren: true, eanCodesBeheren: true, klantenBeheren: true, verkoopkanalenBeheren: true,
    myparcelInstellingen: true, betaalgatewayInstellingen: true, marktplaatsKoppelingen: true,
    gebruikersBeheren: true, ownersAdminsBeheren: true, rollenRechtenToewijzen: true, bedrijfsgegevensBewerken: true,
    betaalmethodenOverzicht: true, geblokkeerdeAccountsBeheren: true, activiteitenlogBekijken: true, activiteitenlogWijzigen: true, testmodus: true,
    eigenProfielBewerken: true, eigenWachtwoordWijzigen: true, mfaSchakelen: false, puntensaldoBekijken: false,
  );

  static const adminPreset = UserPermissions(
    productenBewerken: true, uitgelichteProducten: true, productenBlokkeren: true,
    eigenBestelhistorie: true, bezorgstatusVolgen: true, alleBestellingenBeheren: true, bestellingenVerzenden: true,
    leadsInzien: true, leadsWijzigen: true, leadEmailsVersturen: true, leadsVerwijderen: true, leadsExporteren: true, statistiekenBekijken: true, kortingscodesBeheren: true,
    emailTemplatesBeheren: true, smtpInstellingen: false, orderTemplatesBewerken: true,
    aboutTekstBewerken: true, impressiesBeheren: true, categoryVideosBeheren: true, reviewPlatformsBeheren: true,
    zendingenOverzicht: true, productgewichtenBeheren: true, verpakkingenBeheren: true, voorraadBeheren: true, voorraadImporteren: true, eanCodesBeheren: true, klantenBeheren: true, verkoopkanalenBeheren: true,
    myparcelInstellingen: false, betaalgatewayInstellingen: false, marktplaatsKoppelingen: true,
    gebruikersBeheren: false, ownersAdminsBeheren: false, rollenRechtenToewijzen: false, bedrijfsgegevensBewerken: false,
    betaalmethodenOverzicht: true, geblokkeerdeAccountsBeheren: true, activiteitenlogBekijken: true, activiteitenlogWijzigen: false, testmodus: false,
    eigenProfielBewerken: true, eigenWachtwoordWijzigen: true, mfaSchakelen: false, puntensaldoBekijken: false,
  );

  static const wederverkoperPreset = UserPermissions(
    eigenBestelhistorie: true, bezorgstatusVolgen: true,
    eigenProfielBewerken: true, eigenWachtwoordWijzigen: true,
    puntensaldoBekijken: true,
  );

  static const prospectPreset = UserPermissions();

  static const klantPreset = UserPermissions(
    eigenBestelhistorie: true, bezorgstatusVolgen: true,
    eigenProfielBewerken: true, eigenWachtwoordWijzigen: true,
    mfaSchakelen: true,
  );

  static const userPreset = UserPermissions();

  /// Returns the default preset for a given role.
  static UserPermissions defaultForRole(UserType role) {
    switch (role) {
      case UserType.owner: return ownerPreset;
      case UserType.admin: return adminPreset;
      case UserType.wederverkoper: return wederverkoperPreset;
      case UserType.prospect: return prospectPreset;
      case UserType.klant: return klantPreset;
      case UserType.user: return userPreset;
    }
  }

  // Legacy aliases for backward compatibility
  static const owner = ownerPreset;
  static const admin = adminPreset;
  static const all = ownerPreset;
  static const catalogOnly = userPreset;
  static const readOnly = userPreset;

  // Legacy getter aliases so existing code keeps compiling
  bool get inzien => leadsInzien;
  bool get wijzigen => leadsWijzigen;
  bool get emailsVersturen => leadEmailsVersturen;
  bool get verwijderen => leadsVerwijderen;
  bool get exporteren => leadsExporteren;

  /// All permission keys used for the role-matrix screen.
  static const allKeys = <String>[
    'producten_bewerken', 'uitgelichte_producten', 'producten_blokkeren',
    'eigen_bestelhistorie', 'bezorgstatus_volgen', 'alle_bestellingen_beheren', 'bestellingen_verzenden',
    'leads_inzien', 'leads_wijzigen', 'lead_emails_versturen', 'leads_verwijderen', 'leads_exporteren', 'statistieken_bekijken', 'kortingscodes_beheren',
    'email_templates_beheren', 'smtp_instellingen', 'order_templates_bewerken',
    'about_tekst_bewerken', 'impressies_beheren', 'category_videos_beheren', 'review_platforms_beheren',
    'zendingen_overzicht', 'productgewichten_beheren', 'verpakkingen_beheren', 'voorraad_beheren', 'voorraad_importeren', 'ean_codes_beheren', 'klanten_beheren', 'verkoopkanalen_beheren',
    'myparcel_instellingen', 'betaalgateway_instellingen', 'marktplaats_koppelingen',
    'gebruikers_beheren', 'owners_admins_beheren', 'rollen_rechten_toewijzen', 'bedrijfsgegevens_bewerken',
    'betaalmethoden_overzicht', 'geblokkeerde_accounts_beheren', 'activiteitenlog_bekijken', 'activiteitenlog_wijzigen', 'testmodus',
    'eigen_profiel_bewerken', 'eigen_wachtwoord_wijzigen', 'mfa_schakelen', 'puntensaldo_bekijken',
  ];

  /// Human-readable labels grouped by category.
  static const keyLabels = <String, String>{
    'producten_bewerken': 'Producten bewerken',
    'uitgelichte_producten': 'Uitgelichte producten beheren',
    'producten_blokkeren': 'Producten blokkeren/deblokkeren',
    'eigen_bestelhistorie': 'Eigen bestelhistorie bekijken',
    'bezorgstatus_volgen': 'Bezorgstatus volgen (dashboard)',
    'alle_bestellingen_beheren': 'Alle bestellingen beheren',
    'bestellingen_verzenden': 'Bestellingen verzenden',
    'leads_inzien': 'Leads inzien',
    'leads_wijzigen': 'Leads wijzigen',
    'lead_emails_versturen': 'Lead-emails versturen',
    'leads_verwijderen': 'Leads verwijderen',
    'leads_exporteren': 'Leads exporteren',
    'statistieken_bekijken': 'Statistieken bekijken',
    'kortingscodes_beheren': 'Kortingscodes beheren',
    'email_templates_beheren': 'E-mail templates beheren',
    'smtp_instellingen': 'SMTP instellingen',
    'order_templates_bewerken': 'Order-templates bewerken',
    'about_tekst_bewerken': 'About-tekst bewerken',
    'impressies_beheren': 'Impressies beheren',
    'category_videos_beheren': 'Category-videos beheren',
    'review_platforms_beheren': 'Review-platforms beheren',
    'zendingen_overzicht': 'Zendingen overzicht',
    'productgewichten_beheren': 'Productgewichten beheren',
    'verpakkingen_beheren': 'Verpakkingen beheren',
    'voorraad_beheren': 'Voorraad beheren',
    'voorraad_importeren': 'Voorraad importeren (CSV)',
    'ean_codes_beheren': 'EAN-codes beheren',
    'klanten_beheren': 'Klanten beheren',
    'verkoopkanalen_beheren': 'Verkoopkanalen beheren',
    'myparcel_instellingen': 'MyParcel instellingen',
    'betaalgateway_instellingen': 'Betaalgateway instellingen',
    'marktplaats_koppelingen': 'Marktplaatskoppelingen (eBay/Bol/Amazon)',
    'gebruikers_beheren': 'Gebruikers beheren',
    'owners_admins_beheren': 'Owners/Admins beheren',
    'rollen_rechten_toewijzen': 'Rollen/rechten toewijzen',
    'bedrijfsgegevens_bewerken': 'Bedrijfsgegevens bewerken',
    'betaalmethoden_overzicht': 'Betaalmethoden overzicht',
    'geblokkeerde_accounts_beheren': 'Geblokkeerde accounts beheren',
    'activiteitenlog_bekijken': 'Activiteitenlog bekijken',
    'activiteitenlog_wijzigen': 'Activiteitenlog wijzigen',
    'testmodus': 'Testmodus (impersonatie)',
    'eigen_profiel_bewerken': 'Eigen profiel bewerken',
    'eigen_wachtwoord_wijzigen': 'Eigen wachtwoord wijzigen',
    'mfa_schakelen': 'MFA in/uitschakelen',
    'puntensaldo_bekijken': 'Puntensaldo bekijken',
  };

  /// Category groupings for the role-matrix screen.
  static const keyCategories = <String, List<String>>{
    'Catalogus & Producten': ['producten_bewerken', 'uitgelichte_producten', 'producten_blokkeren'],
    'Orders & Bestellingen': ['eigen_bestelhistorie', 'bezorgstatus_volgen', 'alle_bestellingen_beheren', 'bestellingen_verzenden'],
    'Leads & Marketing': ['leads_inzien', 'leads_wijzigen', 'lead_emails_versturen', 'leads_verwijderen', 'leads_exporteren', 'statistieken_bekijken', 'kortingscodes_beheren'],
    'E-mail & Communicatie': ['email_templates_beheren', 'smtp_instellingen', 'order_templates_bewerken'],
    'Website & Content': ['about_tekst_bewerken', 'impressies_beheren', 'category_videos_beheren', 'review_platforms_beheren'],
    'Verzending & Voorraad': ['zendingen_overzicht', 'productgewichten_beheren', 'verpakkingen_beheren', 'voorraad_beheren', 'voorraad_importeren', 'ean_codes_beheren', 'klanten_beheren', 'verkoopkanalen_beheren'],
    'Koppelingen': ['myparcel_instellingen', 'betaalgateway_instellingen', 'marktplaats_koppelingen'],
    'Beheer & Beveiliging': ['gebruikers_beheren', 'owners_admins_beheren', 'rollen_rechten_toewijzen', 'bedrijfsgegevens_bewerken', 'betaalmethoden_overzicht', 'geblokkeerde_accounts_beheren', 'activiteitenlog_bekijken', 'activiteitenlog_wijzigen', 'testmodus'],
    'Profiel & Account': ['eigen_profiel_bewerken', 'eigen_wachtwoord_wijzigen', 'mfa_schakelen', 'puntensaldo_bekijken'],
  };

  bool getByKey(String key) => toJson()[key] == true;

  /// Validates that allKeys, keyLabels, keyCategories, toJson, and fromJson
  /// are all in sync. Call this in debug mode at app startup to catch drift
  /// early. Returns a list of inconsistency messages (empty = all OK).
  static List<String> validateSchema() {
    final errors = <String>[];
    final inst = const UserPermissions();
    final jsonKeys = inst.toJson().keys.toSet();

    // allKeys must match toJson keys exactly
    final allKeysSet = allKeys.toSet();
    final missingInAllKeys = jsonKeys.difference(allKeysSet);
    final extraInAllKeys = allKeysSet.difference(jsonKeys);
    if (missingInAllKeys.isNotEmpty) errors.add('Keys in toJson but missing from allKeys: $missingInAllKeys');
    if (extraInAllKeys.isNotEmpty) errors.add('Keys in allKeys but missing from toJson: $extraInAllKeys');

    // keyLabels must cover all allKeys
    final labelKeys = keyLabels.keys.toSet();
    final missingLabels = allKeysSet.difference(labelKeys);
    final extraLabels = labelKeys.difference(allKeysSet);
    if (missingLabels.isNotEmpty) errors.add('Keys missing from keyLabels: $missingLabels');
    if (extraLabels.isNotEmpty) errors.add('Extra keys in keyLabels not in allKeys: $extraLabels');

    // keyCategories must cover all allKeys exactly once
    final catKeys = <String>{};
    for (final keys in keyCategories.values) catKeys.addAll(keys);
    final missingInCats = allKeysSet.difference(catKeys);
    final extraInCats = catKeys.difference(allKeysSet);
    if (missingInCats.isNotEmpty) errors.add('Keys missing from keyCategories: $missingInCats');
    if (extraInCats.isNotEmpty) errors.add('Extra keys in keyCategories not in allKeys: $extraInCats');

    // fromJson round-trip: ownerPreset → toJson → fromJson should equal ownerPreset
    final rt = UserPermissions.fromJson(ownerPreset.toJson());
    for (final key in allKeys) {
      if (rt.getByKey(key) != ownerPreset.getByKey(key)) {
        errors.add('fromJson round-trip mismatch for key "$key"');
      }
    }
    return errors;
  }

  UserPermissions withKey(String key, bool value) {
    final json = toJson();
    json[key] = value;
    return UserPermissions.fromJson(json);
  }

  factory UserPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserPermissions();
    return UserPermissions(
      productenBewerken: (json['producten_bewerken'] as bool?) ?? false,
      uitgelichteProducten: (json['uitgelichte_producten'] as bool?) ?? false,
      productenBlokkeren: (json['producten_blokkeren'] as bool?) ?? false,
      eigenBestelhistorie: (json['eigen_bestelhistorie'] as bool?) ?? false,
      bezorgstatusVolgen: (json['bezorgstatus_volgen'] as bool?) ?? false,
      alleBestellingenBeheren: (json['alle_bestellingen_beheren'] as bool?) ?? false,
      bestellingenVerzenden: (json['bestellingen_verzenden'] as bool?) ?? false,
      leadsInzien: (json['leads_inzien'] as bool?) ?? (json['inzien'] as bool?) ?? false,
      leadsWijzigen: (json['leads_wijzigen'] as bool?) ?? (json['wijzigen'] as bool?) ?? false,
      leadEmailsVersturen: (json['lead_emails_versturen'] as bool?) ?? (json['emails_versturen'] as bool?) ?? false,
      leadsVerwijderen: (json['leads_verwijderen'] as bool?) ?? (json['verwijderen'] as bool?) ?? false,
      leadsExporteren: (json['leads_exporteren'] as bool?) ?? (json['exporteren'] as bool?) ?? false,
      statistiekenBekijken: (json['statistieken_bekijken'] as bool?) ?? false,
      kortingscodesBeheren: (json['kortingscodes_beheren'] as bool?) ?? false,
      emailTemplatesBeheren: (json['email_templates_beheren'] as bool?) ?? false,
      smtpInstellingen: (json['smtp_instellingen'] as bool?) ?? false,
      orderTemplatesBewerken: (json['order_templates_bewerken'] as bool?) ?? false,
      aboutTekstBewerken: (json['about_tekst_bewerken'] as bool?) ?? false,
      impressiesBeheren: (json['impressies_beheren'] as bool?) ?? false,
      categoryVideosBeheren: (json['category_videos_beheren'] as bool?) ?? false,
      reviewPlatformsBeheren: (json['review_platforms_beheren'] as bool?) ?? false,
      zendingenOverzicht: (json['zendingen_overzicht'] as bool?) ?? false,
      productgewichtenBeheren: (json['productgewichten_beheren'] as bool?) ?? false,
      verpakkingenBeheren: (json['verpakkingen_beheren'] as bool?) ?? false,
      voorraadBeheren: (json['voorraad_beheren'] as bool?) ?? false,
      voorraadImporteren: (json['voorraad_importeren'] as bool?) ?? false,
      eanCodesBeheren: (json['ean_codes_beheren'] as bool?) ?? false,
      klantenBeheren: (json['klanten_beheren'] as bool?) ?? false,
      verkoopkanalenBeheren: (json['verkoopkanalen_beheren'] as bool?) ?? false,
      myparcelInstellingen: (json['myparcel_instellingen'] as bool?) ?? false,
      betaalgatewayInstellingen: (json['betaalgateway_instellingen'] as bool?) ?? false,
      marktplaatsKoppelingen: (json['marktplaats_koppelingen'] as bool?) ?? false,
      gebruikersBeheren: (json['gebruikers_beheren'] as bool?) ?? false,
      ownersAdminsBeheren: (json['owners_admins_beheren'] as bool?) ?? false,
      rollenRechtenToewijzen: (json['rollen_rechten_toewijzen'] as bool?) ?? false,
      bedrijfsgegevensBewerken: (json['bedrijfsgegevens_bewerken'] as bool?) ?? false,
      betaalmethodenOverzicht: (json['betaalmethoden_overzicht'] as bool?) ?? false,
      geblokkeerdeAccountsBeheren: (json['geblokkeerde_accounts_beheren'] as bool?) ?? false,
      activiteitenlogBekijken: (json['activiteitenlog_bekijken'] as bool?) ?? false,
      activiteitenlogWijzigen: (json['activiteitenlog_wijzigen'] as bool?) ?? false,
      testmodus: (json['testmodus'] as bool?) ?? false,
      eigenProfielBewerken: (json['eigen_profiel_bewerken'] as bool?) ?? false,
      eigenWachtwoordWijzigen: (json['eigen_wachtwoord_wijzigen'] as bool?) ?? false,
      mfaSchakelen: (json['mfa_schakelen'] as bool?) ?? false,
      puntensaldoBekijken: (json['puntensaldo_bekijken'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'producten_bewerken': productenBewerken,
    'uitgelichte_producten': uitgelichteProducten,
    'producten_blokkeren': productenBlokkeren,
    'eigen_bestelhistorie': eigenBestelhistorie,
    'bezorgstatus_volgen': bezorgstatusVolgen,
    'alle_bestellingen_beheren': alleBestellingenBeheren,
    'bestellingen_verzenden': bestellingenVerzenden,
    'leads_inzien': leadsInzien,
    'leads_wijzigen': leadsWijzigen,
    'lead_emails_versturen': leadEmailsVersturen,
    'leads_verwijderen': leadsVerwijderen,
    'leads_exporteren': leadsExporteren,
    'statistieken_bekijken': statistiekenBekijken,
    'kortingscodes_beheren': kortingscodesBeheren,
    'email_templates_beheren': emailTemplatesBeheren,
    'smtp_instellingen': smtpInstellingen,
    'order_templates_bewerken': orderTemplatesBewerken,
    'about_tekst_bewerken': aboutTekstBewerken,
    'impressies_beheren': impressiesBeheren,
    'category_videos_beheren': categoryVideosBeheren,
    'review_platforms_beheren': reviewPlatformsBeheren,
    'zendingen_overzicht': zendingenOverzicht,
    'productgewichten_beheren': productgewichtenBeheren,
    'verpakkingen_beheren': verpakkingenBeheren,
    'voorraad_beheren': voorraadBeheren,
    'voorraad_importeren': voorraadImporteren,
    'ean_codes_beheren': eanCodesBeheren,
    'klanten_beheren': klantenBeheren,
    'verkoopkanalen_beheren': verkoopkanalenBeheren,
    'myparcel_instellingen': myparcelInstellingen,
    'betaalgateway_instellingen': betaalgatewayInstellingen,
    'marktplaats_koppelingen': marktplaatsKoppelingen,
    'gebruikers_beheren': gebruikersBeheren,
    'owners_admins_beheren': ownersAdminsBeheren,
    'rollen_rechten_toewijzen': rollenRechtenToewijzen,
    'bedrijfsgegevens_bewerken': bedrijfsgegevensBewerken,
    'betaalmethoden_overzicht': betaalmethodenOverzicht,
    'geblokkeerde_accounts_beheren': geblokkeerdeAccountsBeheren,
    'activiteitenlog_bekijken': activiteitenlogBekijken,
    'activiteitenlog_wijzigen': activiteitenlogWijzigen,
    'testmodus': testmodus,
    'eigen_profiel_bewerken': eigenProfielBewerken,
    'eigen_wachtwoord_wijzigen': eigenWachtwoordWijzigen,
    'mfa_schakelen': mfaSchakelen,
    'puntensaldo_bekijken': puntensaldoBekijken,
  };

  UserPermissions copyWith({
    bool? productenBewerken, bool? uitgelichteProducten, bool? productenBlokkeren,
    bool? eigenBestelhistorie, bool? bezorgstatusVolgen, bool? alleBestellingenBeheren, bool? bestellingenVerzenden,
    bool? leadsInzien, bool? leadsWijzigen, bool? leadEmailsVersturen, bool? leadsVerwijderen, bool? leadsExporteren, bool? statistiekenBekijken, bool? kortingscodesBeheren,
    bool? emailTemplatesBeheren, bool? smtpInstellingen, bool? orderTemplatesBewerken,
    bool? aboutTekstBewerken, bool? impressiesBeheren, bool? categoryVideosBeheren, bool? reviewPlatformsBeheren,
    bool? zendingenOverzicht, bool? productgewichtenBeheren, bool? verpakkingenBeheren, bool? voorraadBeheren, bool? voorraadImporteren, bool? eanCodesBeheren, bool? klantenBeheren, bool? verkoopkanalenBeheren,
    bool? myparcelInstellingen, bool? betaalgatewayInstellingen, bool? marktplaatsKoppelingen,
    bool? gebruikersBeheren, bool? ownersAdminsBeheren, bool? rollenRechtenToewijzen, bool? bedrijfsgegevensBewerken,
    bool? betaalmethodenOverzicht, bool? geblokkeerdeAccountsBeheren, bool? activiteitenlogBekijken, bool? activiteitenlogWijzigen, bool? testmodus,
    bool? eigenProfielBewerken, bool? eigenWachtwoordWijzigen, bool? mfaSchakelen, bool? puntensaldoBekijken,
  }) {
    return UserPermissions(
      productenBewerken: productenBewerken ?? this.productenBewerken,
      uitgelichteProducten: uitgelichteProducten ?? this.uitgelichteProducten,
      productenBlokkeren: productenBlokkeren ?? this.productenBlokkeren,
      eigenBestelhistorie: eigenBestelhistorie ?? this.eigenBestelhistorie,
      bezorgstatusVolgen: bezorgstatusVolgen ?? this.bezorgstatusVolgen,
      alleBestellingenBeheren: alleBestellingenBeheren ?? this.alleBestellingenBeheren,
      bestellingenVerzenden: bestellingenVerzenden ?? this.bestellingenVerzenden,
      leadsInzien: leadsInzien ?? this.leadsInzien,
      leadsWijzigen: leadsWijzigen ?? this.leadsWijzigen,
      leadEmailsVersturen: leadEmailsVersturen ?? this.leadEmailsVersturen,
      leadsVerwijderen: leadsVerwijderen ?? this.leadsVerwijderen,
      leadsExporteren: leadsExporteren ?? this.leadsExporteren,
      statistiekenBekijken: statistiekenBekijken ?? this.statistiekenBekijken,
      kortingscodesBeheren: kortingscodesBeheren ?? this.kortingscodesBeheren,
      emailTemplatesBeheren: emailTemplatesBeheren ?? this.emailTemplatesBeheren,
      smtpInstellingen: smtpInstellingen ?? this.smtpInstellingen,
      orderTemplatesBewerken: orderTemplatesBewerken ?? this.orderTemplatesBewerken,
      aboutTekstBewerken: aboutTekstBewerken ?? this.aboutTekstBewerken,
      impressiesBeheren: impressiesBeheren ?? this.impressiesBeheren,
      categoryVideosBeheren: categoryVideosBeheren ?? this.categoryVideosBeheren,
      reviewPlatformsBeheren: reviewPlatformsBeheren ?? this.reviewPlatformsBeheren,
      zendingenOverzicht: zendingenOverzicht ?? this.zendingenOverzicht,
      productgewichtenBeheren: productgewichtenBeheren ?? this.productgewichtenBeheren,
      verpakkingenBeheren: verpakkingenBeheren ?? this.verpakkingenBeheren,
      voorraadBeheren: voorraadBeheren ?? this.voorraadBeheren,
      voorraadImporteren: voorraadImporteren ?? this.voorraadImporteren,
      eanCodesBeheren: eanCodesBeheren ?? this.eanCodesBeheren,
      klantenBeheren: klantenBeheren ?? this.klantenBeheren,
      verkoopkanalenBeheren: verkoopkanalenBeheren ?? this.verkoopkanalenBeheren,
      myparcelInstellingen: myparcelInstellingen ?? this.myparcelInstellingen,
      betaalgatewayInstellingen: betaalgatewayInstellingen ?? this.betaalgatewayInstellingen,
      marktplaatsKoppelingen: marktplaatsKoppelingen ?? this.marktplaatsKoppelingen,
      gebruikersBeheren: gebruikersBeheren ?? this.gebruikersBeheren,
      ownersAdminsBeheren: ownersAdminsBeheren ?? this.ownersAdminsBeheren,
      rollenRechtenToewijzen: rollenRechtenToewijzen ?? this.rollenRechtenToewijzen,
      bedrijfsgegevensBewerken: bedrijfsgegevensBewerken ?? this.bedrijfsgegevensBewerken,
      betaalmethodenOverzicht: betaalmethodenOverzicht ?? this.betaalmethodenOverzicht,
      geblokkeerdeAccountsBeheren: geblokkeerdeAccountsBeheren ?? this.geblokkeerdeAccountsBeheren,
      activiteitenlogBekijken: activiteitenlogBekijken ?? this.activiteitenlogBekijken,
      activiteitenlogWijzigen: activiteitenlogWijzigen ?? this.activiteitenlogWijzigen,
      testmodus: testmodus ?? this.testmodus,
      eigenProfielBewerken: eigenProfielBewerken ?? this.eigenProfielBewerken,
      eigenWachtwoordWijzigen: eigenWachtwoordWijzigen ?? this.eigenWachtwoordWijzigen,
      mfaSchakelen: mfaSchakelen ?? this.mfaSchakelen,
      puntensaldoBekijken: puntensaldoBekijken ?? this.puntensaldoBekijken,
    );
  }
}

enum InviteStatus { uitgenodigd, geregistreerd, inactief }

class AppUser {
  final String? id;
  final String? authUserId;
  final String email;
  final UserType userType;
  final InviteStatus status;
  final UserPermissions permissions;
  final bool isAdmin;
  final bool isOwner;
  final bool isParticulier;
  // NAW (bezorgadres)
  final String? voornaam;
  final String? achternaam;
  final String? adres;
  final String? postcode;
  final String? woonplaats;
  final String? regio;
  final String? telefoon;
  // Factuuradres (null = zelfde als bezorgadres)
  final String? factuurAdres;
  final String? factuurPostcode;
  final String? factuurWoonplaats;
  // Bedrijfsgegevens
  final String? bedrijfsnaam;
  final String? btwNummer;
  final bool btwGevalideerd;
  final DateTime? btwValidatieDatum;
  final bool btwVerlegd;
  final String? iban;
  // Locatie & kortingen
  final String landCode;
  final double kortingPermanent;
  final double kortingTijdelijk;
  final DateTime? kortingGeldigTot;
  final DateTime? createdAt;

  const AppUser({
    this.id,
    this.authUserId,
    required this.email,
    this.userType = UserType.user,
    this.status = InviteStatus.uitgenodigd,
    this.permissions = const UserPermissions(),
    this.isAdmin = false,
    this.isOwner = false,
    this.isParticulier = true,
    this.voornaam,
    this.achternaam,
    this.adres,
    this.postcode,
    this.woonplaats,
    this.regio,
    this.telefoon,
    this.factuurAdres,
    this.factuurPostcode,
    this.factuurWoonplaats,
    this.bedrijfsnaam,
    this.btwNummer,
    this.btwGevalideerd = false,
    this.btwValidatieDatum,
    this.btwVerlegd = false,
    this.iban,
    this.landCode = 'NL',
    this.kortingPermanent = 0,
    this.kortingTijdelijk = 0,
    this.kortingGeldigTot,
    this.createdAt,
  });

  factory AppUser.fromDbRow(Map<String, dynamic> row) {
    return AppUser(
      id: row['id'] as String?,
      authUserId: row['auth_user_id'] as String?,
      email: ((row['email'] as String?) ?? '').toLowerCase(),
      userType: UserTypeExt.fromDb(row['user_type'] as String?),
      status: _parseStatus(row['status'] as String?),
      permissions: UserPermissions.fromJson(row['permissions'] as Map<String, dynamic>?),
      isAdmin: (row['is_admin'] as bool?) ?? false,
      isOwner: (row['is_owner'] as bool?) ?? false,
      isParticulier: (row['is_particulier'] as bool?) ?? true,
      voornaam: row['voornaam'] as String?,
      achternaam: row['achternaam'] as String?,
      adres: row['adres'] as String?,
      postcode: row['postcode'] as String?,
      woonplaats: row['woonplaats'] as String?,
      regio: row['regio'] as String?,
      telefoon: row['telefoon'] as String?,
      factuurAdres: row['factuur_adres'] as String?,
      factuurPostcode: row['factuur_postcode'] as String?,
      factuurWoonplaats: row['factuur_woonplaats'] as String?,
      bedrijfsnaam: row['bedrijfsnaam'] as String?,
      btwNummer: row['btw_nummer'] as String?,
      btwGevalideerd: (row['btw_gevalideerd'] as bool?) ?? false,
      btwValidatieDatum: row['btw_validatie_datum'] != null
          ? DateTime.tryParse(row['btw_validatie_datum'] as String) : null,
      btwVerlegd: (row['btw_verlegd'] as bool?) ?? false,
      iban: row['iban'] as String?,
      landCode: (row['land_code'] as String?) ?? 'NL',
      kortingPermanent: (row['korting_permanent'] as num?)?.toDouble() ?? 0,
      kortingTijdelijk: (row['korting_tijdelijk'] as num?)?.toDouble() ?? 0,
      kortingGeldigTot: row['korting_geldig_tot'] != null
          ? DateTime.tryParse(row['korting_geldig_tot'] as String) : null,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
    );
  }

  static InviteStatus _parseStatus(String? val) {
    switch (val) {
      case 'geregistreerd': return InviteStatus.geregistreerd;
      case 'inactief': return InviteStatus.inactief;
      default: return InviteStatus.uitgenodigd;
    }
  }

  Map<String, dynamic> toDbRow() {
    final map = <String, dynamic>{
      'email': email.toLowerCase(),
      'user_type': userType.dbValue,
      'status': status == InviteStatus.geregistreerd ? 'geregistreerd'
          : status == InviteStatus.inactief ? 'inactief' : 'uitgenodigd',
      'is_particulier': isParticulier,
      'btw_gevalideerd': btwGevalideerd,
      'btw_verlegd': btwVerlegd,
      'land_code': landCode,
      'korting_permanent': kortingPermanent,
      'korting_tijdelijk': kortingTijdelijk,
      'permissions': permissions.toJson(),
      'is_admin': isAdmin,
      'is_owner': isOwner,
    };
    if (authUserId != null) map['auth_user_id'] = authUserId;
    if (voornaam != null) map['voornaam'] = voornaam;
    if (achternaam != null) map['achternaam'] = achternaam;
    if (adres != null) map['adres'] = adres;
    if (postcode != null) map['postcode'] = postcode;
    if (woonplaats != null) map['woonplaats'] = woonplaats;
    if (regio != null) map['regio'] = regio;
    if (telefoon != null) map['telefoon'] = telefoon;
    if (factuurAdres != null) map['factuur_adres'] = factuurAdres;
    if (factuurPostcode != null) map['factuur_postcode'] = factuurPostcode;
    if (factuurWoonplaats != null) map['factuur_woonplaats'] = factuurWoonplaats;
    if (bedrijfsnaam != null) map['bedrijfsnaam'] = bedrijfsnaam;
    if (btwNummer != null) map['btw_nummer'] = btwNummer;
    if (btwValidatieDatum != null) map['btw_validatie_datum'] = btwValidatieDatum!.toIso8601String();
    if (iban != null) map['iban'] = iban;
    if (kortingGeldigTot != null) map['korting_geldig_tot'] = kortingGeldigTot!.toIso8601String();
    return map;
  }

  Map<String, dynamic> toJson() => {
    'email': email.toLowerCase(),
    'status': status == InviteStatus.geregistreerd ? 'geregistreerd' : 'uitgenodigd',
    'permissions': permissions.toJson(),
    'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  AppUser copyWith({
    String? id, String? authUserId, String? email, UserType? userType,
    InviteStatus? status, UserPermissions? permissions, bool? isAdmin,
    bool? isOwner, bool? isParticulier, String? voornaam, String? achternaam,
    String? adres, String? postcode, String? woonplaats, String? regio,
    String? telefoon, String? factuurAdres, String? factuurPostcode,
    String? factuurWoonplaats, String? bedrijfsnaam, String? btwNummer,
    bool? btwGevalideerd, DateTime? btwValidatieDatum, bool? btwVerlegd,
    String? iban, String? landCode, double? kortingPermanent,
    double? kortingTijdelijk, DateTime? kortingGeldigTot,
  }) {
    return AppUser(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      isAdmin: isAdmin ?? this.isAdmin,
      isOwner: isOwner ?? this.isOwner,
      isParticulier: isParticulier ?? this.isParticulier,
      voornaam: voornaam ?? this.voornaam,
      achternaam: achternaam ?? this.achternaam,
      adres: adres ?? this.adres,
      postcode: postcode ?? this.postcode,
      woonplaats: woonplaats ?? this.woonplaats,
      regio: regio ?? this.regio,
      telefoon: telefoon ?? this.telefoon,
      factuurAdres: factuurAdres ?? this.factuurAdres,
      factuurPostcode: factuurPostcode ?? this.factuurPostcode,
      factuurWoonplaats: factuurWoonplaats ?? this.factuurWoonplaats,
      bedrijfsnaam: bedrijfsnaam ?? this.bedrijfsnaam,
      btwNummer: btwNummer ?? this.btwNummer,
      btwGevalideerd: btwGevalideerd ?? this.btwGevalideerd,
      btwValidatieDatum: btwValidatieDatum ?? this.btwValidatieDatum,
      btwVerlegd: btwVerlegd ?? this.btwVerlegd,
      iban: iban ?? this.iban,
      landCode: landCode ?? this.landCode,
      kortingPermanent: kortingPermanent ?? this.kortingPermanent,
      kortingTijdelijk: kortingTijdelijk ?? this.kortingTijdelijk,
      kortingGeldigTot: kortingGeldigTot ?? this.kortingGeldigTot,
      createdAt: createdAt,
    );
  }

  bool get hasFactuurAdres =>
      factuurAdres != null && factuurAdres!.isNotEmpty;

  String get effectiefFactuurAdres => factuurAdres ?? adres ?? '';
  String get effectiefFactuurPostcode => factuurPostcode ?? postcode ?? '';
  String get effectiefFactuurWoonplaats => factuurWoonplaats ?? woonplaats ?? '';

  String get volledigeNaam {
    final parts = <String>[];
    if (voornaam != null && voornaam!.isNotEmpty) parts.add(voornaam!);
    if (achternaam != null && achternaam!.isNotEmpty) parts.add(achternaam!);
    return parts.isEmpty ? email : parts.join(' ');
  }

  double get effectiveKorting {
    final now = DateTime.now();
    final tijdelijkGeldig = kortingGeldigTot == null || kortingGeldigTot!.isAfter(now);
    final tijdelijk = tijdelijkGeldig ? kortingTijdelijk : 0.0;
    return kortingPermanent > tijdelijk ? kortingPermanent : tijdelijk;
  }

  bool get isBedrijf => !isParticulier;
}

class ImpersonationProfile {
  final String label;
  final UserType userType;
  final UserPermissions permissions;
  final bool isAdmin;
  final bool isOwner;
  final bool isParticulier;
  final String landCode;
  final double kortingPermanent;
  final double kortingTijdelijk;
  final bool btwGevalideerd;

  const ImpersonationProfile({
    required this.label,
    required this.userType,
    required this.permissions,
    this.isAdmin = false,
    this.isOwner = false,
    this.isParticulier = true,
    this.landCode = 'NL',
    this.kortingPermanent = 0,
    this.kortingTijdelijk = 0,
    this.btwGevalideerd = false,
  });

  static const presets = <String, ImpersonationProfile>{
    'user': ImpersonationProfile(
      label: 'User (geen account)',
      userType: UserType.user,
      permissions: UserPermissions.userPreset,
      isParticulier: true,
    ),
    'prospect': ImpersonationProfile(
      label: 'Prospect (uitgenodigd, niet geregistreerd)',
      userType: UserType.prospect,
      permissions: UserPermissions.prospectPreset,
      isParticulier: true,
    ),
    'klant_particulier': ImpersonationProfile(
      label: 'Klant (particulier, NL)',
      userType: UserType.klant,
      permissions: UserPermissions.klantPreset,
      isParticulier: true,
      landCode: 'NL',
    ),
    'klant_bedrijf_nl': ImpersonationProfile(
      label: 'Klant (bedrijf, NL)',
      userType: UserType.klant,
      permissions: UserPermissions.klantPreset,
      isParticulier: false,
      landCode: 'NL',
      btwGevalideerd: true,
    ),
    'klant_bedrijf_eu': ImpersonationProfile(
      label: 'Klant (bedrijf, DE, BTW verlegd)',
      userType: UserType.klant,
      permissions: UserPermissions.klantPreset,
      isParticulier: false,
      landCode: 'DE',
      btwGevalideerd: true,
    ),
    'wederverkoper': ImpersonationProfile(
      label: 'Wederverkoper (korting, MFA verplicht)',
      userType: UserType.wederverkoper,
      permissions: UserPermissions.wederverkoperPreset,
      isParticulier: false,
      landCode: 'NL',
      kortingPermanent: 10,
      btwGevalideerd: true,
    ),
    'admin': ImpersonationProfile(
      label: 'Admin (geen koppelingen/gebruikersbeheer)',
      userType: UserType.admin,
      permissions: UserPermissions.adminPreset,
      isAdmin: true,
    ),
  };
}

class UserService {
  final _client = Supabase.instance.client;
  static const _table = 'ventoz_users';
  bool _useLegacy = false;

  /// Active impersonation profile, null means no impersonation.
  static ImpersonationProfile? _impersonation;

  static bool get isImpersonating => _impersonation != null;
  static ImpersonationProfile? get impersonation => _impersonation;
  static String? get impersonationLabel => _impersonation?.label;

  static Future<void> startImpersonation(ImpersonationProfile profile) async {
    final isOwner = await UserService().isRealOwner();
    if (!isOwner) throw Exception('Alleen de eigenaar mag impersonation gebruiken.');
    _impersonation = profile;
    onPermissionsChanged?.call();
  }

  static void stopImpersonation() {
    _impersonation = null;
    onPermissionsChanged?.call();
  }

  /// Hook called when permissions change (impersonation, role update, etc.).
  /// Set by the router to invalidate its permission cache.
  static void Function()? onPermissionsChanged;

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentUserEmail => _client.auth.currentUser?.email;

  // ─── Table detection ───

  Future<bool> _hasUsersTable() async {
    try {
      await _client.from(_table).select('id').limit(0);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureTable() async {
    _useLegacy = !(await _hasUsersTable());
  }

  // ─── Owner ───

  Future<String?> _getOwnerEmail() async {
    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select('email').eq('is_owner', true).limit(1);
        if (rows.isNotEmpty) {
          return (rows.first as Map<String, dynamic>)['email'] as String?;
        }
      } catch (_) {}
    }
    try {
      final List<dynamic> response = await _client
          .from('app_settings').select('value').eq('key', 'app_owner');
      if (response.isEmpty) return null;
      final raw = response.first['value'];
      if (raw is Map) return (raw['email'] as String?)?.toLowerCase();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setOwner(String email) async {
    await _client.from('app_settings').upsert({
      'key': 'app_owner',
      'value': {'email': email.toLowerCase()},
    }, onConflict: 'key');
  }

  bool _isOwnerEmail(String email, String? ownerEmail) {
    if (ownerEmail == null) return false;
    return email.toLowerCase() == ownerEmail;
  }

  /// Retourneert true als de huidige gebruiker eigenaar is.
  /// Bij impersonation wordt het profiel gerespecteerd.
  Future<bool> isCurrentUserOwner() async {
    if (_impersonation != null) return _impersonation!.isOwner;
    return isRealOwner();
  }

  /// Altijd de echte eigenaar-status, ongeacht impersonation.
  /// Gebruik voor impersonation-menu en stopknop.
  Future<bool> isRealOwner() async {
    final email = currentUserEmail;
    if (email == null) return false;
    final owner = await _getOwnerEmail();
    return _isOwnerEmail(email, owner);
  }

  // ─── Admin ───

  Future<bool> isCurrentUserAdmin() async {
    if (_impersonation != null) return _impersonation!.isAdmin;

    await _ensureTable();
    final email = currentUserEmail;
    if (email == null) return false;

    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select('is_admin, is_owner')
            .eq('email', email.toLowerCase()).limit(1);
        if (rows.isNotEmpty) {
          final row = rows.first as Map<String, dynamic>;
          return (row['is_admin'] as bool?) == true || (row['is_owner'] as bool?) == true;
        }
      } catch (_) {}
    }

    final owner = await _getOwnerEmail();
    if (owner == null) {
      await _setOwner(email);
      await _setAdminEmails([email]);
      if (!_useLegacy) {
        await _upsertUserRow(AppUser(
          email: email, userType: UserType.owner,
          status: InviteStatus.geregistreerd, permissions: UserPermissions.ownerPreset,
          isAdmin: true, isOwner: true, authUserId: currentUserId,
        ));
      }
      await _saveInvitedUsers([AppUser(
        email: email, userType: UserType.owner,
        status: InviteStatus.geregistreerd,
        permissions: UserPermissions.ownerPreset, isAdmin: true, isOwner: true,
      )]);
      return true;
    }
    if (_isOwnerEmail(email, owner)) return true;

    final admins = await _getAdminEmails();
    return admins.contains(email.toLowerCase());
  }

  Future<List<String>> _getAdminEmails() async {
    try {
      final List<dynamic> response = await _client
          .from('app_settings').select('value').eq('key', 'admin_users');
      if (response.isEmpty) return [];
      final raw = response.first['value'];
      if (raw is Map && raw['emails'] is List) {
        return (raw['emails'] as List).cast<String>().map((e) => e.toLowerCase()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _setAdminEmails(List<String> emails) async {
    final normalized = emails.map((e) => e.toLowerCase()).toList();
    await _client.from('app_settings').upsert({
      'key': 'admin_users',
      'value': {'emails': normalized},
    }, onConflict: 'key');
  }

  // ─── Authorization ───

  Future<bool> isUserAuthorized() async {
    await _ensureTable();
    final email = currentUserEmail;
    if (email == null) return false;

    final owner = await _getOwnerEmail();
    if (owner == null) return true;
    if (_isOwnerEmail(email, owner)) return true;

    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select('status, is_admin, is_owner')
            .eq('email', email.toLowerCase()).limit(1);
        if (rows.isNotEmpty) {
          final row = rows.first as Map<String, dynamic>;
          if ((row['is_admin'] as bool?) == true) return true;
          if ((row['is_owner'] as bool?) == true) return true;
          final status = row['status'] as String?;
          return status == 'geregistreerd' || status == 'uitgenodigd';
        }
      } catch (_) {}
    }

    final admins = await _getAdminEmails();
    if (admins.contains(email.toLowerCase())) return true;

    final users = await _getInvitedUsers();
    final match = users.firstWhere(
      (u) => u['email'] == email.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (match.isEmpty) return false;
    final status = match['status'] as String?;
    return status == 'geregistreerd' || status == 'uitgenodigd';
  }

  Future<bool> isEmailInvited(String email) async {
    await _ensureTable();
    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select('id')
            .eq('email', email.toLowerCase()).limit(1);
        if (rows.isNotEmpty) return true;
      } catch (_) {}
    }
    final users = await _getInvitedUsers();
    return users.any((u) => u['email'] == email.toLowerCase());
  }

  Future<void> markAsRegistered(String email) async {
    await _ensureTable();
    if (!_useLegacy) {
      try {
        await _client.from(_table).update({
          'status': 'geregistreerd',
          'auth_user_id': _client.auth.currentUser?.id,
        }).eq('email', email.toLowerCase());
      } catch (_) {
        // RLS may block this if auth_user_id is null; ensureCurrentUserRegistered
        // will retry on next login.
      }
    }
    final users = await _getInvitedUsers();
    for (final u in users) {
      if (u['email'] == email.toLowerCase()) {
        u['status'] = 'geregistreerd';
      }
    }
    await _client.from('app_settings').upsert({
      'key': 'invited_users',
      'value': {'users': users},
    }, onConflict: 'key');
  }

  /// Ensures the current user's ventoz_users row has auth_user_id set and
  /// status promoted to 'geregistreerd'. Called after every successful login
  /// to fix rows where markAsRegistered failed due to RLS.
  Future<void> promoteIfNeeded() async {
    await _ensureTable();
    if (_useLegacy) return;
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return;
    final email = user.email!.toLowerCase();

    try {
      final List<dynamic> rows = await _client
          .from(_table).select('status, auth_user_id')
          .eq('email', email).limit(1);
      if (rows.isEmpty) return;
      final row = rows.first as Map<String, dynamic>;
      final needsUpdate = row['auth_user_id'] == null ||
          row['status'] != 'geregistreerd';
      if (!needsUpdate) return;

      await _client.from(_table).update({
        'status': 'geregistreerd',
        'auth_user_id': user.id,
      }).eq('email', email);
    } catch (_) {}
  }

  // ─── Permissions ───

  Future<UserPermissions> getCurrentUserPermissions() async {
    if (_impersonation != null) return _impersonation!.permissions;

    await _ensureTable();
    final email = currentUserEmail;
    if (email == null) return const UserPermissions();

    final owner = await _getOwnerEmail();
    if (owner != null && _isOwnerEmail(email, owner)) return UserPermissions.ownerPreset;

    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select()
            .eq('email', email.toLowerCase()).limit(1);
        if (rows.isNotEmpty) {
          final user = AppUser.fromDbRow(rows.first as Map<String, dynamic>);
          if (user.isOwner) return UserPermissions.ownerPreset;
          final stored = user.permissions;
          final hasStoredPermissions = stored != const UserPermissions();
          if (hasStoredPermissions) return stored;
          if (user.isAdmin) return await _rolePermissionsFor(user.userType, fallback: UserPermissions.adminPreset);
          return await _rolePermissionsFor(user.userType);
        }
      } catch (_) {}
    }

    final users = await _getInvitedUsers();
    final match = users.firstWhere(
      (u) => u['email'] == email.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );

    final admins = await _getAdminEmails();
    final isAdm = admins.contains(email.toLowerCase());

    if (match.isEmpty) {
      return isAdm
          ? await _rolePermissionsFor(UserType.admin, fallback: UserPermissions.adminPreset)
          : const UserPermissions();
    }

    if (isAdm) return await _rolePermissionsFor(UserType.admin, fallback: UserPermissions.adminPreset);
    return UserPermissions.fromJson(match['permissions'] as Map<String, dynamic>?);
  }

  /// Resolves permissions for a role: first checks the owner-editable
  /// role_permissions matrix in app_settings, falls back to hardcoded presets.
  Future<UserPermissions> _rolePermissionsFor(UserType role, {UserPermissions? fallback}) async {
    try {
      final saved = await loadRolePermissions();
      if (saved != null && saved.containsKey(role.dbValue)) {
        return saved[role.dbValue]!;
      }
    } catch (_) {}
    return fallback ?? UserPermissions.defaultForRole(role);
  }

  Future<AppUser?> getCurrentUser() async {
    if (_impersonation != null) {
      final p = _impersonation!;
      return AppUser(
        email: currentUserEmail ?? 'test@ventoz.nl',
        userType: p.userType,
        status: InviteStatus.geregistreerd,
        permissions: p.permissions,
        isAdmin: p.isAdmin,
        isOwner: p.isOwner,
        isParticulier: p.isParticulier,
        landCode: p.landCode,
        kortingPermanent: p.kortingPermanent,
        kortingTijdelijk: p.kortingTijdelijk,
        btwGevalideerd: p.btwGevalideerd,
        btwValidatieDatum: p.btwGevalideerd ? DateTime.now() : null,
      );
    }

    await _ensureTable();
    final email = currentUserEmail;
    if (email == null) return null;

    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select()
            .eq('email', email.toLowerCase()).limit(1);
        if (rows.isNotEmpty) {
          return AppUser.fromDbRow(rows.first as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    return null;
  }

  // ─── Users CRUD ───

  Future<List<Map<String, dynamic>>> _getInvitedUsers() async {
    try {
      final List<dynamic> response = await _client
          .from('app_settings').select('value').eq('key', 'invited_users');
      if (response.isEmpty) return [];
      final raw = response.first['value'];
      if (raw is Map && raw['users'] is List) {
        return (raw['users'] as List).cast<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveInvitedUsers(List<AppUser> users) async {
    await _client.from('app_settings').upsert({
      'key': 'invited_users',
      'value': {'users': users.map((u) => u.toJson()).toList()},
    }, onConflict: 'key');
  }

  Future<void> _upsertUserRow(AppUser user) async {
    if (_useLegacy) return;
    try {
      await _client.from(_table).upsert(user.toDbRow(), onConflict: 'email');
    } on PostgrestException catch (_) {}
  }

  Future<List<AppUser>> fetchUsers() async {
    await _ensureTable();

    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select().order('created_at', ascending: true);
        return rows.cast<Map<String, dynamic>>()
            .map((r) => AppUser.fromDbRow(r)).toList();
      } catch (_) {}
    }

    final admins = await _getAdminEmails();
    final owner = await _getOwnerEmail();
    final rawUsers = await _getInvitedUsers();
    return rawUsers.map((u) {
      final email = ((u['email'] as String?) ?? '').toLowerCase();
      final isOwn = owner != null && email == owner;
      final isAdm = admins.contains(email) || isOwn;
      return AppUser(
        email: email,
        status: (u['status'] as String?) == 'geregistreerd'
            ? InviteStatus.geregistreerd : InviteStatus.uitgenodigd,
        permissions: UserPermissions.fromJson(u['permissions'] as Map<String, dynamic>?),
        isAdmin: isAdm, isOwner: isOwn,
        createdAt: DateTime.tryParse((u['created_at'] as String?) ?? ''),
      );
    }).toList();
  }

  Future<void> _requireUserManagement() async {
    final perms = await getCurrentUserPermissions();
    if (!perms.gebruikersBeheren) {
      throw Exception('Je hebt geen recht om gebruikers te beheren.');
    }
  }

  Future<void> inviteUser({
    required String email,
    required UserPermissions permissions,
    UserType userType = UserType.klant,
    String landCode = 'NL',
    bool isParticulier = true,
  }) async {
    await _requireUserManagement();
    await _ensureTable();

    final existing = await fetchUsers();
    if (existing.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      throw Exception('Dit e-mailadres is al uitgenodigd of geregistreerd.');
    }

    final sanitized = await _rolePermissionsFor(userType);

    final user = AppUser(
      email: email.toLowerCase(),
      userType: userType,
      status: InviteStatus.uitgenodigd,
      permissions: sanitized,
      landCode: landCode,
      isParticulier: isParticulier,
      createdAt: DateTime.now(),
    );

    if (!_useLegacy) {
      await _upsertUserRow(user);
    }

    existing.add(user);
    await _saveInvitedUsers(existing);
  }

  /// Invite a lead as a user when sending an email with a download link.
  /// Returns true if a new invitation was created, false if email already exists.
  /// Uses a SECURITY DEFINER RPC function so medewerkers without
  /// gebruikersBeheren can trigger this from lead emails.
  Future<bool> inviteFromLead({
    required String email,
    UserType userType = UserType.prospect,
    String? bedrijfsnaam,
    String? landCode,
    double? kortingsPercentage,
  }) async {
    try {
      final result = await _client.rpc('invite_from_lead', params: {
        'p_email': email.toLowerCase(),
        'p_user_type': userType.dbValue,
        'p_bedrijfsnaam': bedrijfsnaam,
        'p_land_code': landCode ?? 'NL',
        'p_korting_permanent': (userType == UserType.wederverkoper && kortingsPercentage != null)
            ? kortingsPercentage : 0,
      });
      return result == true;
    } on PostgrestException catch (e) {
      if (e.message.contains('duplicate') || e.message.contains('already')) {
        return false;
      }
      rethrow;
    }
  }

  /// Update only safe profile fields for the currently signed-in user.
  /// Does NOT require gebruikersBeheren permission.
  Future<void> updateOwnProfile(AppUser updated) async {
    await _ensureTable();
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Niet ingelogd');
    final currentEmail = session.user.email?.toLowerCase() ?? '';
    if (updated.email.toLowerCase() != currentEmail) {
      throw Exception('Je kunt alleen je eigen profiel bijwerken.');
    }

    final existing = await getCurrentUser();
    if (existing == null) throw Exception('Gebruiker niet gevonden');

    final safe = existing.copyWith(
      voornaam: updated.voornaam,
      achternaam: updated.achternaam,
      adres: updated.adres,
      postcode: updated.postcode,
      woonplaats: updated.woonplaats,
      telefoon: updated.telefoon,
      factuurAdres: updated.factuurAdres,
      factuurPostcode: updated.factuurPostcode,
      factuurWoonplaats: updated.factuurWoonplaats,
      bedrijfsnaam: updated.bedrijfsnaam,
      iban: updated.iban,
    );

    if (!_useLegacy) {
      try {
        await _client.from(_table).upsert(safe.toDbRow(), onConflict: 'email');
      } on PostgrestException catch (e) {
        throw Exception('Bijwerken mislukt: ${e.message}');
      }
    }

    final legacyUsers = await _getInvitedUsers();
    for (var i = 0; i < legacyUsers.length; i++) {
      if (((legacyUsers[i]['email'] as String?) ?? '').toLowerCase() == currentEmail) {
        legacyUsers[i] = safe.toJson();
        break;
      }
    }
    await _client.from('app_settings').upsert({
      'key': 'invited_users',
      'value': {'users': legacyUsers},
    }, onConflict: 'key');
  }

  Future<void> updateUser(AppUser updated) async {
    await _requireUserManagement();
    await _ensureTable();

    final owner = await _getOwnerEmail();
    if (_isOwnerEmail(updated.email, owner) && !await isCurrentUserOwner()) {
      throw Exception('De rechten van de eigenaar kunnen niet worden gewijzigd.');
    }

    // 1. Update ventoz_users table
    if (!_useLegacy) {
      try {
        await _client.from(_table).upsert(
          updated.toDbRow(),
          onConflict: 'email',
        );
      } on PostgrestException catch (e) {
        throw Exception('Bijwerken mislukt: ${e.message}');
      }
    }

    // 2. Also update legacy app_settings for backwards compat
    final legacyUsers = await _getInvitedUsers();
    final normalizedEmail = updated.email.toLowerCase();
    bool found = false;
    for (var i = 0; i < legacyUsers.length; i++) {
      if (((legacyUsers[i]['email'] as String?) ?? '').toLowerCase() == normalizedEmail) {
        legacyUsers[i] = updated.toJson();
        found = true;
        break;
      }
    }
    if (!found) legacyUsers.add(updated.toJson());
    await _client.from('app_settings').upsert({
      'key': 'invited_users',
      'value': {'users': legacyUsers},
    }, onConflict: 'key');
  }

  Future<void> updatePermissions(String email, UserPermissions permissions) async {
    await _requireUserManagement();
    await _ensureTable();

    final normalized = email.toLowerCase();

    final owner = await _getOwnerEmail();
    if (_isOwnerEmail(normalized, owner)) {
      throw Exception('De rechten van de eigenaar kunnen niet worden gewijzigd.');
    }

    // 1. Update ventoz_users table
    if (!_useLegacy) {
      try {
        await _client.from(_table)
            .update({'permissions': permissions.toJson()})
            .eq('email', normalized);
      } on PostgrestException catch (e) {
        throw Exception('Rechten bijwerken mislukt: ${e.message}');
      }
    }

    // 2. Update legacy app_settings
    final legacyUsers = await _getInvitedUsers();
    for (final u in legacyUsers) {
      if (((u['email'] as String?) ?? '').toLowerCase() == normalized) {
        u['permissions'] = permissions.toJson();
        break;
      }
    }
    await _client.from('app_settings').upsert({
      'key': 'invited_users',
      'value': {'users': legacyUsers},
    }, onConflict: 'key');
  }

  Future<void> toggleAdmin(String email) async {
    final isOwner = await isCurrentUserOwner();
    if (!isOwner) throw Exception('Alleen de eigenaar mag admin-rechten toekennen.');

    final owner = await _getOwnerEmail();
    if (_isOwnerEmail(email, owner)) {
      throw Exception('De eigenaar heeft altijd beheerdersrechten.');
    }

    final admins = await _getAdminEmails();
    final normalized = email.toLowerCase();
    final wasAdmin = admins.contains(normalized);
    if (wasAdmin) {
      admins.remove(normalized);
    } else {
      admins.add(normalized);
    }
    await _setAdminEmails(admins);

    if (!_useLegacy) {
      try {
        await _client.from(_table)
            .update({'is_admin': !wasAdmin})
            .eq('email', normalized);
      } on PostgrestException catch (e) {
        throw Exception('Admin-status wijzigen mislukt: ${e.message}');
      }
    }
  }

  Future<void> removeUser(String email) async {
    await _requireUserManagement();
    await _ensureTable();

    final normalized = email.toLowerCase();

    final owner = await _getOwnerEmail();
    if (_isOwnerEmail(normalized, owner)) {
      throw Exception('Het eigenaar-account kan niet worden verwijderd.');
    }
    if (normalized == currentUserEmail?.toLowerCase()) {
      throw Exception('Je kunt je eigen account niet verwijderen.');
    }

    // 1. Remove from legacy app_settings first
    final legacyUsers = await _getInvitedUsers();
    final filteredLegacy = legacyUsers.where((u) =>
        ((u['email'] as String?) ?? '').toLowerCase() != normalized).toList();
    await _client.from('app_settings').upsert({
      'key': 'invited_users',
      'value': {'users': filteredLegacy},
    }, onConflict: 'key');

    // 2. Remove from admin list
    final admins = await _getAdminEmails();
    admins.remove(normalized);
    await _setAdminEmails(admins);

    // 3. Delete Supabase auth account via Edge Function
    try {
      await _client.functions.invoke('delete-auth-user', body: {'email': normalized});
    } catch (e) {
      debugPrint('Auth account deletion failed (may not exist): $e');
    }

    // 4. Remove from ventoz_users table
    if (!_useLegacy) {
      try {
        await _client.from(_table).delete().eq('email', normalized);
      } on PostgrestException catch (e) {
        throw Exception('Verwijderen uit database mislukt: ${e.message}');
      }
    }
  }

  Future<void> ensureCurrentUserRegistered() async {
    await _ensureTable();
    final user = _client.auth.currentUser;
    if (user == null) return;
    final email = user.email;
    if (email == null) return;

    if (!_useLegacy) {
      try {
        final List<dynamic> rows = await _client
            .from(_table).select('id')
            .eq('email', email.toLowerCase()).limit(1);
        if (rows.isEmpty) {
          final ownerEmail = await _getOwnerEmail();
          final isFirstUser = ownerEmail == null;
          final role = isFirstUser ? UserType.owner : UserType.klant;
          final perms = isFirstUser ? UserPermissions.ownerPreset : UserPermissions.klantPreset;
          await _upsertUserRow(AppUser(
            email: email, authUserId: user.id,
            userType: role,
            status: InviteStatus.geregistreerd,
            permissions: perms,
            isAdmin: isFirstUser, isOwner: isFirstUser,
          ));
        } else {
          await _client.from(_table)
              .update({'auth_user_id': user.id, 'status': 'geregistreerd'})
              .eq('email', email.toLowerCase());
        }
      } catch (_) {}
    }

    final users = await _getInvitedUsers();
    final exists = users.any((u) => u['email'] == email.toLowerCase());
    if (!exists) {
      final ownerEmail = await _getOwnerEmail();
      final isFirstUser = ownerEmail == null;
      final role = isFirstUser ? UserType.owner : UserType.klant;
      final perms = isFirstUser ? UserPermissions.ownerPreset : UserPermissions.klantPreset;
      final all = await fetchUsers();
      all.add(AppUser(
        email: email, userType: role,
        status: InviteStatus.geregistreerd,
        permissions: perms, createdAt: DateTime.now(),
      ));
      await _saveInvitedUsers(all);
    }
  }

  // ─── BTW update ───

  Future<void> updateBtwValidation(String email, {
    required bool gevalideerd, String? btwNummer,
  }) async {
    await _ensureTable();
    if (!_useLegacy) {
      try {
        final updates = <String, dynamic>{
          'btw_gevalideerd': gevalideerd,
          'btw_validatie_datum': DateTime.now().toUtc().toIso8601String(),
        };
        if (btwNummer != null) updates['btw_nummer'] = btwNummer;
        await _client.from(_table).update(updates).eq('email', email.toLowerCase());
      } catch (_) {}
    }
  }

  // ─── Language ───

  Future<String> getUserLanguage() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 'nl';
      final List<dynamic> rows = await _client
          .from('app_settings').select('value')
          .eq('key', 'user_lang_$userId');
      if (rows.isEmpty) return 'nl';
      final val = rows.first['value'];
      if (val is Map && val['lang'] is String) return val['lang'] as String;
      return 'nl';
    } catch (_) {
      return 'nl';
    }
  }

  Future<void> setUserLanguage(String lang) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('app_settings').upsert({
      'key': 'user_lang_$userId',
      'value': {'lang': lang},
    }, onConflict: 'key');
  }

  // ─── Role permissions matrix (Owner-editable) ───

  /// Load custom role permissions from app_settings.
  /// Returns null if no overrides have been saved yet (use defaults).
  Future<Map<String, UserPermissions>?> loadRolePermissions() async {
    try {
      final List<dynamic> response = await _client
          .from('app_settings').select('value').eq('key', 'role_permissions');
      if (response.isEmpty) return null;
      final raw = response.first['value'];
      if (raw is! Map) return null;
      final result = <String, UserPermissions>{};
      for (final entry in raw.entries) {
        if (entry.value is Map) {
          result[entry.key as String] = UserPermissions.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  /// Save custom role permissions (Owner only).
  Future<void> saveRolePermissions(Map<String, UserPermissions> perms) async {
    final isOwner = await isCurrentUserOwner();
    if (!isOwner) throw Exception('Alleen de eigenaar mag rolrechten aanpassen.');
    final value = <String, dynamic>{};
    for (final entry in perms.entries) {
      value[entry.key] = entry.value.toJson();
    }
    await _client.from('app_settings').upsert({
      'key': 'role_permissions',
      'value': value,
    }, onConflict: 'key');
  }

  // ─── Prospect flow ───

  /// Promote a prospect to klant after registration, keeping any kortingscode.
  Future<void> promoteProspectToKlant(String email) async {
    await _ensureTable();
    final normalized = email.toLowerCase();
    if (!_useLegacy) {
      try {
        await _client.from(_table).update({
          'user_type': UserType.klant.dbValue,
          'status': 'geregistreerd',
          'permissions': UserPermissions.klantPreset.toJson(),
          'auth_user_id': _client.auth.currentUser?.id,
        }).eq('email', normalized);
      } catch (_) {}
    }
  }

  /// Resolve effective UserType considering is_owner / is_admin flags.
  UserType resolveEffectiveRole(AppUser user) {
    if (user.isOwner) return UserType.owner;
    if (user.isAdmin) return UserType.admin;
    return user.userType;
  }
}
