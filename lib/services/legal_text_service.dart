import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'translate_service.dart';

class LegalTextService {
  static final LegalTextService _instance = LegalTextService._();
  factory LegalTextService() => _instance;
  LegalTextService._();

  final _supabase = Supabase.instance.client;
  final _translator = TranslateService();

  static const pages = <String, String>{
    'legal_terms': 'Leveringsvoorwaarden',
    'legal_privacy': 'Privacy Statement',
    'legal_warranty': 'Garantie',
    'legal_complaints': 'Klachten',
    'legal_returns': 'Retourneren',
  };

  final Map<String, Map<String, String>> _cache = {};

  Future<Map<String, String>> getTexts(String key) async {
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', key)
          .limit(1);
      if (rows.isNotEmpty && rows.first['value'] != null) {
        final raw = rows.first['value'];
        if (raw is Map) {
          final result = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
          _cache[key] = result;
          return result;
        }
        if (raw is String) {
          final decoded = jsonDecode(raw) as Map;
          final result = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          _cache[key] = result;
          return result;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveAndTranslate(
    String key,
    String nlText, {
    void Function(String lang)? onProgress,
  }) async {
    final translations = <String, String>{'nl': nlText};

    final chunks = _splitIntoChunks(nlText, 4500);

    for (final lang in TranslateService.translationTargets) {
      onProgress?.call(lang);
      if (chunks.length == 1) {
        translations[lang] = await _translator.translate(nlText, targetLang: lang);
      } else {
        final translatedChunks = <String>[];
        for (final chunk in chunks) {
          translatedChunks.add(await _translator.translate(chunk, targetLang: lang));
          await Future.delayed(const Duration(milliseconds: 40));
        }
        translations[lang] = translatedChunks.join('\n\n');
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _supabase.from('app_settings').upsert({
      'key': key,
      'value': translations,
    }, onConflict: 'key');
    _cache[key] = translations;
  }

  /// Splits text at paragraph boundaries to stay under character limits.
  List<String> _splitIntoChunks(String text, int maxChars) {
    if (text.length <= maxChars) return [text];

    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final para in paragraphs) {
      if (buffer.length + para.length + 2 > maxChars && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(para);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks;
  }

  void invalidateCache([String? key]) {
    if (key != null) {
      _cache.remove(key);
    } else {
      _cache.clear();
    }
  }

  /// Seeds all 5 legal pages with Dutch source texts and translates them.
  Future<void> seedAllPages({void Function(String key, String lang)? onProgress}) async {
    for (final entry in _seedData.entries) {
      final existing = await getTexts(entry.key);
      if (existing.isNotEmpty) continue;

      await saveAndTranslate(
        entry.key,
        entry.value,
        onProgress: (lang) => onProgress?.call(entry.key, lang),
      );
    }
  }

  static const _seedData = <String, String>{
    'legal_terms': '''Artikel 1 - Definities

In deze voorwaarden wordt verstaan onder:
1. Bedenktijd: de termijn waarbinnen de consument gebruik kan maken van zijn herroepingsrecht;
2. Consument: de natuurlijke persoon die niet handelt in de uitoefening van beroep of bedrijf en een overeenkomst op afstand aangaat met de ondernemer;
3. Dag: kalenderdag;
4. Duurtransactie: een overeenkomst op afstand met betrekking tot een reeks van producten en/of diensten, waarvan de leverings- en/of afnameverplichting in de tijd is gespreid;
5. Duurzame gegevensdrager: elk middel dat de consument of ondernemer in staat stelt om informatie die aan hem persoonlijk is gericht, op te slaan op een manier die toekomstige raadpleging en ongewijzigde reproductie van de opgeslagen informatie mogelijk maakt.
6. Herroepingsrecht: de mogelijkheid voor de consument om binnen de bedenktijd af te zien van de overeenkomst op afstand;
7. Ondernemer: de natuurlijke of rechtspersoon die producten en/of diensten op afstand aan consumenten aanbiedt;
8. Overeenkomst op afstand: een overeenkomst waarbij in het kader van een door de ondernemer georganiseerd systeem voor verkoop op afstand van producten en/of diensten, tot en met het sluiten van de overeenkomst uitsluitend gebruik gemaakt wordt van een of meer technieken voor communicatie op afstand;
9. Techniek voor communicatie op afstand: middel dat kan worden gebruikt voor het sluiten van een overeenkomst, zonder dat consument en ondernemer gelijktijdig in dezelfde ruimte zijn samengekomen.

Artikel 2 - Identiteit van de ondernemer

Ventoz
Dorpsstraat 111
7948 BN Nijeveen
Telefoon: +31 6 10193845
E-mail: info@ventoz.nl
KvK-nummer: 64140814
BTW-identificatienummer: NL854566235B01

Artikel 3 - Toepasselijkheid

1. Deze algemene voorwaarden zijn van toepassing op elk aanbod van de ondernemer en op elke tot stand gekomen overeenkomst op afstand tussen ondernemer en consument.
2. Voordat de overeenkomst op afstand wordt gesloten, wordt de tekst van deze algemene voorwaarden aan de consument beschikbaar gesteld.

Artikel 4 - Het aanbod

1. Indien een aanbod een beperkte geldigheidsduur heeft of onder voorwaarden geschiedt, wordt dit nadrukkelijk in het aanbod vermeld.
2. Het aanbod bevat een volledige en nauwkeurige omschrijving van de aangeboden producten en/of diensten. De beschrijving is voldoende gedetailleerd om een goede beoordeling van het aanbod door de consument mogelijk te maken.

Artikel 5 - De overeenkomst

1. De overeenkomst komt, onder voorbehoud van het bepaalde in lid 4, tot stand op het moment van aanvaarding door de consument van het aanbod en het voldoen aan de daarbij gestelde voorwaarden.
2. Indien de consument het aanbod langs elektronische weg heeft aanvaard, bevestigt de ondernemer onverwijld langs elektronische weg de ontvangst van de aanvaarding van het aanbod.

Artikel 6 - Herroepingsrecht

Bij levering van producten:
1. Bij de aankoop van producten heeft de consument de mogelijkheid de overeenkomst zonder opgave van redenen te ontbinden gedurende 14 dagen. Deze bedenktermijn gaat in op de dag na ontvangst van het product door de consument of een vooraf door de consument aangewezen en aan de ondernemer bekend gemaakte vertegenwoordiger.
2. Tijdens de bedenktijd zal de consument zorgvuldig omgaan met het product en de verpakking. Hij zal het product slechts in die mate uitpakken of gebruiken voor zover dat nodig is om te kunnen beoordelen of hij het product wenst te behouden.

Artikel 7 - Kosten in geval van herroeping

1. Indien de consument gebruik maakt van zijn herroepingsrecht, komen ten hoogste de kosten van terugzending voor zijn rekening.
2. Indien de consument een bedrag betaald heeft, zal de ondernemer dit bedrag zo spoedig mogelijk, doch uiterlijk binnen 14 dagen na herroeping, terugbetalen.

Artikel 8 - Uitsluiting herroepingsrecht

De ondernemer kan het herroepingsrecht van de consument uitsluiten voor producten zoals omschreven in lid 2 en 3. De uitsluiting van het herroepingsrecht geldt slechts indien de ondernemer dit duidelijk in het aanbod, althans tijdig voor het sluiten van de overeenkomst, heeft vermeld.

Artikel 9 - De prijs

1. Gedurende de in het aanbod vermelde geldigheidsduur worden de prijzen van de aangeboden producten en/of diensten niet verhoogd, behoudens prijswijzigingen als gevolg van veranderingen in btw-tarieven.
2. De in het aanbod van producten of diensten genoemde prijzen zijn inclusief btw.

Artikel 10 - Conformiteit en Garantie

1. De ondernemer staat er voor in dat de producten en/of diensten voldoen aan de overeenkomst, de in het aanbod vermelde specificaties, aan de redelijke eisen van deugdelijkheid en/of bruikbaarheid en de op de datum van de totstandkoming van de overeenkomst bestaande wettelijke bepalingen en/of overheidsvoorschriften.

Artikel 11 - Levering en uitvoering

1. De ondernemer zal de grootst mogelijke zorgvuldigheid in acht nemen bij het in ontvangst nemen en bij de uitvoering van bestellingen van producten.
2. Als plaats van levering geldt het adres dat de consument aan het bedrijf kenbaar heeft gemaakt.
3. De ondernemer zal geaccepteerde bestellingen met bekwame spoed doch uiterlijk binnen 30 dagen uitvoeren tenzij een langere leveringstermijn is afgesproken.

Artikel 12 - Duurtransacties: duur, opzegging en verlenging

1. De consument kan een overeenkomst die voor onbepaalde tijd is aangegaan te allen tijde opzeggen met inachtneming van daartoe overeengekomen opzeggingsregels en een opzegtermijn van ten hoogste een maand.

Artikel 13 - Betaling

1. Voor zover niet anders is bepaald in de overeenkomst of aanvullende voorwaarden, dienen de door de consument verschuldigde bedragen te worden voldaan binnen 14 dagen na het ingaan van de bedenktermijn.

Artikel 14 - Klachtenregeling

1. De ondernemer beschikt over een voldoende bekend gemaakte klachtenprocedure en behandelt de klacht overeenkomstig deze klachtenprocedure.
2. Klachten over de uitvoering van de overeenkomst moeten binnen 2 maanden volledig en duidelijk omschreven worden ingediend bij de ondernemer, nadat de consument de gebreken heeft geconstateerd.

Artikel 15 - Geschillen

Op overeenkomsten tussen de ondernemer en de consument waarop deze algemene voorwaarden betrekking hebben, is uitsluitend Nederlands recht van toepassing.

Artikel 16 - Aanvullende of afwijkende bepalingen

Aanvullende dan wel van deze algemene voorwaarden afwijkende bepalingen mogen niet ten nadele van de consument zijn en dienen schriftelijk te worden vastgelegd dan wel op zodanige wijze dat deze door de consument op een toegankelijke manier kunnen worden opgeslagen op een duurzame gegevensdrager.''',

    'legal_privacy': '''Privacy Statement

Ventoz, gevestigd te Dorpsstraat 111, 7948 BN Nijeveen, is verantwoordelijk voor de verwerking van persoonsgegevens zoals weergegeven in deze privacyverklaring.

Wij respecteren de privacy van alle gebruikers van onze site en dragen er zorg voor dat de persoonlijke informatie die u ons verschaft vertrouwelijk wordt behandeld. Wij gebruiken uw gegevens alleen om uw bestelling zo snel en gemakkelijk mogelijk te maken en te verwerken. Voor het overige zullen wij deze gegevens uitsluitend gebruiken met uw toestemming.

Ventoz verwerkt uw persoonsgegevens doordat u gebruik maakt van onze diensten en/of omdat u deze zelf aan ons verstrekt.

Persoonsgegevens die wij verwerken:
- Voor- en achternaam
- Adresgegevens
- Telefoonnummer
- E-mailadres
- Betalingsgegevens

Met welk doel wij persoonsgegevens verwerken:
- Het afhandelen van uw betaling
- Verzenden van uw bestelling
- U te kunnen bellen of e-mailen indien dit nodig is om onze dienstverlening uit te kunnen voeren
- U te informeren over wijzigingen van onze diensten en producten

Hoe lang we persoonsgegevens bewaren:
Ventoz bewaart uw persoonsgegevens niet langer dan strikt nodig is om de doelen te realiseren waarvoor uw gegevens worden verzameld. Wij hanteren een bewaartermijn conform de wettelijke administratieplicht.

Delen van persoonsgegevens met derden:
Ventoz verstrekt uitsluitend aan derden en alleen als dit nodig is voor de uitvoering van onze overeenkomst met u of om te voldoen aan een wettelijke verplichting. Met bedrijven die uw gegevens verwerken in onze opdracht, sluiten wij een verwerkersovereenkomst om te zorgen voor eenzelfde niveau van beveiliging en vertrouwelijkheid van uw gegevens.

Cookies:
Ventoz gebruikt functionele en analytische cookies. Een cookie is een klein tekstbestand dat bij het eerste bezoek aan deze website wordt opgeslagen in de browser van uw computer, tablet of smartphone. De cookies die wij gebruiken zijn noodzakelijk voor de technische werking van de website en uw gebruiksgemak.

Gegevens inzien, aanpassen of verwijderen:
U heeft het recht om uw persoonsgegevens in te zien, te corrigeren of te verwijderen. Daarnaast heeft u het recht om uw eventuele toestemming voor de gegevensverwerking in te trekken of bezwaar te maken tegen de verwerking van uw persoonsgegevens. U kunt een verzoek tot inzage, correctie, verwijdering sturen naar info@ventoz.com.

Beveiligen:
Ventoz neemt de bescherming van uw gegevens serieus en neemt passende maatregelen om misbruik, verlies, onbevoegde toegang, ongewenste openbaarmaking en ongeoorloofde wijziging tegen te gaan.

Contactgegevens:
Ventoz
Dorpsstraat 111
7948 BN Nijeveen
info@ventoz.com
+31 6 10193845

Autoriteit Persoonsgegevens:
Natuurlijk helpen wij u graag verder als u klachten heeft over de verwerking van uw persoonsgegevens. Op grond van de privacywetgeving heeft u ook het recht om een klacht in te dienen bij de Autoriteit Persoonsgegevens.''',

    'legal_warranty': '''Garantie

Ventoz Sails garandeert dat alle Ventoz producten vrij zijn van fabricagefouten in vakmanschap en materialen en dat Ventoz Sails defecte onderdelen (met uitzondering van die veroorzaakt door onzorgvuldig gebruik, ongelukken zoals botsingen en algemene slijtage) zal repareren of vervangen voor een periode van 12 maanden vanaf de datum van aankoop.

Om aanspraak te kunnen maken op garantie dient u contact met ons op te nemen via info@ventoz.com met een beschrijving van het defect en indien mogelijk foto's. Na beoordeling zullen wij u informeren over de verdere procedure.

Deze garantie is van toepassing naast de wettelijke garantierechten van de consument en doet geen afbreuk aan uw rechten op grond van de wet.''',

    'legal_complaints': '''Klachten

Wij raden u aan om eventuele klachten eerst bij ons kenbaar te maken door te mailen naar info@ventoz.com. Wij streven ernaar uw klacht binnen 14 dagen af te handelen.

Leidt dit niet tot een oplossing, dan is het mogelijk om uw geschil aan te melden voor bemiddeling via Stichting WebwinkelKeur (www.webwinkelkeur.nl).

Het is voor consumenten in de EU ook mogelijk om klachten aan te melden via het ODR platform van de Europese Commissie. Dit ODR platform is te vinden op http://ec.europa.eu/odr.

Wanneer uw klacht nog niet elders in behandeling is dan staat het u vrij om uw klacht te deponeren via het platform van de Europese Unie.''',

    'legal_returns': '''Retourneren

U heeft het recht uw bestelling tot 14 dagen na ontvangst zonder opgave van reden te annuleren. U heeft na annulering nogmaals 14 dagen om uw product retour te sturen.

U krijgt dan het volledige orderbedrag inclusief verzendkosten gecrediteerd. Enkel de kosten voor retour van u thuis naar de webwinkel zijn voor eigen rekening. Deze kosten bedragen binnen Nederland circa EUR 6,95 per pakket. Raadpleeg voor de exacte tarieven de website van uw vervoerder.

Indien u gebruik maakt van uw herroepingsrecht, zal het product met alle geleverde toebehoren en indien redelijkerwijze mogelijk in de originele staat en verpakking aan de ondernemer geretourneerd worden.

Om gebruik te maken van dit recht kunt u contact met ons opnemen via info@ventoz.com. Wij zullen vervolgens het verschuldigde orderbedrag binnen 14 dagen na aanmelding van uw retour terugstorten mits het product reeds in goede orde retour ontvangen is.

Retouradres:
Ventoz
Dorpsstraat 111
7948 BN Nijeveen
Nederland''',
  };
}
