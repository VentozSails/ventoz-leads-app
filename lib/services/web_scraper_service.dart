import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_product.dart';
import 'translate_service.dart';
import 'product_image_service.dart';

class SitemapEntry {
  final String url;
  final String? imageUrl;
  const SitemapEntry({required this.url, this.imageUrl});
}

class ScrapeProgress {
  final int total;
  final int current;
  final String currentProduct;
  const ScrapeProgress({required this.total, required this.current, required this.currentProduct});
  double get fraction => total > 0 ? current / total : 0;
}

class SyncWarning {
  final String message;
  final SyncWarningLevel level;
  const SyncWarning(this.message, this.level);
}

enum SyncWarningLevel { info, warning, critical }

class SyncResult {
  final int syncedCount;
  final List<SyncWarning> warnings;
  final bool aborted;
  const SyncResult({required this.syncedCount, this.warnings = const [], this.aborted = false});
}

class WebScraperService {
  static const _sitemapUrl = 'https://ventoz.nl/files/15027/export/sitemap.xml';
  static const _baseHost = 'ventoz.nl';
  final _client = Supabase.instance.client;

  static const _cacheDuration = Duration(minutes: 2);
  static List<CatalogProduct>? _catalogCache;
  static DateTime? _cacheTime;

  static const _skipPaths = {
    '/', '/contactpage/', '/shipment-and-delivery/', '/ventoz/',
    '/privacyverklaring/', '/klachten/', '/retourneren/', '/warranty/',
    '/verzending-origineel/', '/shipping-costs/',
  };

  static const _categoryPages = {
    '/optimist/', '/diversen/', '/ventoz-laserzeil/', '/ventoz-topaz/',
    '/ventoz-splash/', '/ventoz-centaur/', '/valk/', '/beachsailing/',
    '/rs-feva/', '/randmeer/', '/hobie-cat/', '/ventoz-420-470-sails/',
    '/efsix/', '/stormfok/', '/open-bic/', '/nacra-17/', '/sunfish/',
    '/yamaha-seahopper/', '/mirror/', '/fox-22/',
    '/optimist/optimist-trisail-mini/', '/optimist/ventoz-optimist-standard/',
    '/optimist/ventoz-optimist-training/',
  };

  // ─── Sitemap ───

  Future<List<SitemapEntry>> fetchSitemapEntries() async {
    final response = await http.get(Uri.parse(_sitemapUrl));
    if (response.statusCode != 200) {
      throw Exception('Sitemap laden mislukt (${response.statusCode})');
    }

    final xml = response.body;
    final entries = <SitemapEntry>[];
    final seen = <String>{};

    final urlBlocks = RegExp(r'<url>([\s\S]*?)</url>').allMatches(xml);
    for (final block in urlBlocks) {
      final content = block.group(1)!;

      final locMatch = RegExp(r'<loc>(.*?)</loc>').firstMatch(content);
      if (locMatch == null) continue;
      final loc = locMatch.group(1)!.trim();

      final uri = Uri.tryParse(loc);
      if (uri == null || uri.host != _baseHost) continue;

      final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
      if (_skipPaths.contains(path)) continue;
      if (_categoryPages.contains(path)) continue;

      final normalUrl = 'https://$_baseHost$path';
      if (seen.contains(normalUrl)) continue;
      seen.add(normalUrl);

      final imageMatch = RegExp(r'<image:loc>(.*?)</image:loc>').firstMatch(content);
      final imageUrl = imageMatch?.group(1)?.trim();

      entries.add(SitemapEntry(url: normalUrl, imageUrl: imageUrl));
    }
    return entries;
  }

  // ─── Category derivation ───

  String _deriveCategory(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return 'overig';

    if (segments.length >= 2) return segments[0];

    final slug = segments[0];
    if (slug.contains('optimist')) return 'optimist';
    if (slug.contains('laser') || slug.contains('ilca')) return 'ventoz-laserzeil';
    if (slug.contains('topaz') || slug.contains('topper')) return 'ventoz-topaz';
    if (slug.contains('splash')) return 'ventoz-splash';
    if (slug.contains('strandzeil') || slug.contains('blokart') || slug.contains('giek') || slug.contains('mast-voor')) return 'beachsailing';
    if (slug.contains('centaur')) return 'ventoz-centaur';
    if (slug.contains('feva')) return 'rs-feva';
    if (slug.contains('polyvalk') || slug.contains('valk')) return 'valk';
    if (slug.contains('randmeer')) return 'randmeer';
    if (slug.contains('hobie')) return 'hobie-cat';
    if (slug.contains('420') || slug.contains('470')) return 'ventoz-420-470-sails';
    if (slug.contains('efsix')) return 'efsix';
    if (slug.contains('sunfish') || slug.contains('minifish')) return 'sunfish';
    if (slug.contains('stormfok')) return 'stormfok';
    if (slug.contains('open-bic')) return 'open-bic';
    if (slug.contains('nacra')) return 'nacra-17';
    if (slug.contains('seahopper') || slug.contains('yamaha')) return 'yamaha-seahopper';
    if (slug.contains('mirror')) return 'mirror';
    if (slug.contains('fox')) return 'fox-22';
    if (slug.contains('schoot') || slug.contains('katrol') || slug.contains('nummers') ||
        slug.contains('letters') || slug.contains('zeilzak') || slug.contains('zeillatten') ||
        slug.contains('pulley') || slug.contains('masttop') || slug.contains('ondermast')) {
      return 'diversen';
    }
    return 'overig';
  }

  // ─── Page scraping ───

  Future<CatalogProduct?> scrapeProductPage(String url, String? sitemapImageUrl, {bool scrapeImages = false}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final doc = html_parser.parse(response.body);
      var title = doc.querySelector('h1')?.text.trim() ?? '';
      if (title.isEmpty) return null;

      if (title.startsWith('- ')) title = title.substring(2).trim();
      if (title.isEmpty) return null;

      final bodyText = doc.body?.text ?? '';

      final prijs = _extractPrice(bodyText);
      // Check raw HTML for availability — more reliable than parsed body text
      final inStock = response.body.contains('>InStock<') || bodyText.contains('InStock');

      if (prijs == null && !inStock) return null;

      final artikelnummer = _extractArtikelnummer(bodyText);
      final staffel = _extractStaffelprijzen(bodyText);
      final categorie = _deriveCategory(url);
      final seo = _extractSeo(doc);

      final descEl = doc.querySelector('div[itemprop="description"]')
          ?? doc.querySelector('span[itemprop="description"]');
      final parsed = _parseDescription(descEl);

      final specsTabel = parsed['specsTabel'] as Map<String, String>?;
      String? luff = parsed['luff'] as String?;
      String? foot = parsed['foot'] as String?;
      String? sailArea = parsed['sailArea'] as String?;

      if (luff == null && foot == null && sailArea == null) {
        final fallback = _extractSpecs(bodyText);
        luff = fallback['luff'];
        foot = fallback['foot'];
        sailArea = fallback['sailArea'];
      }

      // Extract all product images when requested
      List<String> extraImages = const [];
      String? mainImage = sitemapImageUrl;
      if (scrapeImages) {
        final imageResult = _extractProductImages(doc, response.body);
        mainImage = imageResult['main'] ?? sitemapImageUrl;
        extraImages = (imageResult['extra'] as List<String>?) ?? const [];
      }

      return CatalogProduct(
        naam: title,
        artikelnummer: artikelnummer,
        categorie: categorie,
        prijs: prijs,
        staffelprijzen: staffel.isNotEmpty ? staffel : null,
        beschrijving: parsed['beschrijving'] as String?,
        afbeeldingUrl: mainImage,
        webshopUrl: url,
        luff: luff,
        foot: foot,
        sailArea: sailArea,
        specsTabel: specsTabel,
        materiaal: parsed['materiaal'] as String?,
        inclusief: parsed['inclusief'] as String?,
        extraAfbeeldingen: extraImages,
        inStock: inStock,
        seoTitle: seo['title'],
        seoDescription: seo['description'],
        seoKeywords: seo['keywords'],
        canonicalUrl: seo['canonical'],
        ogImage: seo['ogImage'],
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Field extraction helpers ───

  double? _extractPrice(String text) {
    final pricePatterns = [
      RegExp(r'(\d+[\.,]\d{2})\s*\n\s*InStock'),
      RegExp(r'€\s*(\d+[\.,]\d{2})'),
      RegExp(r'(\d{2,})\.\d{2}'),
    ];
    for (final pattern in pricePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)!.replaceAll(',', '.');
        final val = double.tryParse(raw);
        if (val != null && val > 1 && val < 10000) return val;
      }
    }
    return null;
  }

  String? _extractArtikelnummer(String text) {
    final match = RegExp(r'(\d{4}[A-Za-z]+)\s').firstMatch(text);
    return match?.group(1);
  }

  /// Parses the itemprop="description" element into structured data.
  /// The specs table is converted to inline text within the description,
  /// producing a readable, flowing product description.
  Map<String, dynamic> _parseDescription(Element? descEl) {
    if (descEl == null) return {};

    // --- 1. Extract specs table before removing it from the DOM ---
    Map<String, String>? specsTabel;
    String? luff, foot, sailArea;
    List<String> specsLines = [];

    final table = descEl.querySelector('table');
    if (table != null) {
      specsTabel = _parseSpecsTable(table);
      if (specsTabel != null && specsTabel.isNotEmpty) {
        for (final entry in specsTabel.entries) {
          final header = entry.key.toLowerCase();
          final val = entry.value;

          // Determine friendly Dutch label and unit
          String label;
          String unit;
          if (header.contains('luff') || header.contains('voorlijk')) {
            label = 'Voorlijk';
            unit = 'cm';
            luff = '$val cm';
          } else if (header.contains('foot') || header.contains('onderlijk')) {
            label = 'Onderlijk';
            unit = 'cm';
            foot = '$val cm';
          } else if (header.contains('achterlijk')) {
            label = 'Achterlijk';
            unit = 'cm';
          } else if (header.contains('bovenlijk')) {
            label = 'Bovenlijk';
            unit = 'cm';
          } else if (header.contains('sail area') || header.contains('oppervlakte') || header.contains('area')) {
            label = 'Oppervlakte';
            unit = 'm²';
            sailArea = '$val m²';
          } else {
            label = entry.key.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
            unit = '';
          }

          final hasUnit = val.contains('cm') || val.contains('m²') || val.contains('m2');
          specsLines.add('$label: $val${!hasUnit && unit.isNotEmpty ? ' $unit' : ''}');
        }
      }
      table.remove();
    }

    // --- 2. Convert remaining HTML to clean text ---
    for (final a in descEl.querySelectorAll('a')) {
      if (a.text.contains('Terug naar overzicht')) a.remove();
    }

    String? materiaal;
    String? inclusief;

    final html = descEl.innerHtml;

    final rawParts = html
        .replaceAll(RegExp(r'<br\s*/?\s*>'), '\n')
        .replaceAll(RegExp(r'<li[^>]*>'), '\n• ')
        .replaceAll(RegExp(r'</li>'), '')
        .replaceAll(RegExp(r'<ul[^>]*>|</ul>'), '\n')
        .replaceAll(RegExp(r'<strong>|</strong>|<b>|</b>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .replaceAll(RegExp(r'  +'), ' ');

    final lines = rawParts
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final descLines = <String>[];
    for (final line in lines) {
      if (_isJunkLine(line)) continue;

      final matLower = line.toLowerCase();
      if (matLower.contains('dacron') || matLower.contains('zeildoek') || matLower.contains('doek')) {
        final matMatch = RegExp(r'(?:gemaakt van|uitgevoerd in)\s+(.+)', caseSensitive: false).firstMatch(line);
        if (matMatch != null && materiaal == null) {
          materiaal = matMatch.group(1)!.replaceAll(RegExp(r'[.,]\s*$'), '').trim();
        }
      }

      if (matLower.contains('geleverd') && (matLower.contains('inclusief') || matLower.contains('incl'))) {
        final inclMatch = RegExp(r'(?:geleverd[,]?\s*)(?:inclusief|incl\.?)\s+(.+)', caseSensitive: false).firstMatch(line);
        if (inclMatch != null && inclusief == null) {
          inclusief = inclMatch.group(1)!.replaceAll(RegExp(r'[.,]\s*$'), '').trim();
        }
      }

      descLines.add(line);
    }

    // --- 3. Insert specs as text lines into the description ---
    // Find the best insertion point: after the last prose paragraph before
    // the "geleverd inclusief" / "Gratis verzending" line, or at the end.
    if (specsLines.isNotEmpty) {
      int insertIdx = descLines.length;
      for (var i = 0; i < descLines.length; i++) {
        final lower = descLines[i].toLowerCase();
        if (lower.contains('geleverd')) {
          insertIdx = i;
          break;
        }
      }
      descLines.insert(insertIdx, '---');
      descLines.insertAll(insertIdx + 1, specsLines);
      descLines.insert(insertIdx + 1 + specsLines.length, '---');
    }

    final beschrijving = _collapseDescription(descLines);

    return {
      'beschrijving': beschrijving,
      'specsTabel': (specsTabel != null && specsTabel.isNotEmpty) ? specsTabel : null,
      'luff': luff,
      'foot': foot,
      'sailArea': sailArea,
      'materiaal': materiaal,
      'inclusief': inclusief,
    };
  }

  /// Joins lines into readable text with blank lines between each line/paragraph.
  String? _collapseDescription(List<String> lines) {
    if (lines.isEmpty) return null;
    final result = lines.join('\n\n');
    if (result.length > 3000) return result.substring(0, 3000);
    return result.isNotEmpty ? result : null;
  }

  /// Normalizes cell text: collapses whitespace, removes non-breaking spaces.
  String _cleanCellText(String raw) {
    return raw
        .replaceAll('\u00A0', ' ') // non-breaking space
        .replaceAll('\u00C2', '')  // stray UTF-8 artifact
        .replaceAll(RegExp(r'[\t\n\r]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  /// Parses an HTML <table> with a header row and a data row into a map.
  Map<String, String>? _parseSpecsTable(Element table) {
    final rows = table.querySelectorAll('tr');
    if (rows.length < 2) return null;

    final headerCells = rows.first.querySelectorAll('td, th');
    final dataCells = rows.last.querySelectorAll('td, th');

    if (headerCells.length < 2 || dataCells.length < 2) return null;

    final result = <String, String>{};
    final firstHeaderClean = _cleanCellText(headerCells.first.text).toLowerCase();
    final firstDataClean = _cleanCellText(dataCells.first.text).toLowerCase();
    final startIdx = (firstHeaderClean.isEmpty ||
        firstHeaderClean == 'dimensions' ||
        firstDataClean == 'dimensions') ? 1 : 0;

    for (var i = startIdx; i < headerCells.length && i < dataCells.length; i++) {
      final header = _cleanCellText(headerCells[i].text);
      final value = _cleanCellText(dataCells[i].text);
      if (header.isNotEmpty && value.isNotEmpty) {
        result[header] = value;
      }
    }
    return result.isNotEmpty ? result : null;
  }

  static final _specHeaderPattern = RegExp(
    r'^(?:luff|foot|sail\s*area|voorlijk|achterlijk|onderlijk|bovenlijk|oppervlakte|zeiloppervlak(?:te)?|dimensions)'
    r'(?:\s*\((?:cm|m2|m²)\))?$',
    caseSensitive: false,
  );

  bool _isJunkLine(String line) {
    final lower = line.toLowerCase().trim();

    if (lower.contains('gratis verzending') || lower.contains('gratis bezorging')) return true;

    // Table header/label remnants (e.g. "Luff (cm)", "Voorlijk", "Dimensions")
    if (_specHeaderPattern.hasMatch(lower)) return true;
    // "(cm)" or "(m2)" as standalone fragments
    if (RegExp(r'^\((?:cm|m2)\)$').hasMatch(lower)) return true;

    if (RegExp(r'^\d{4}[A-Za-z]').hasMatch(line)) return true;
    if (RegExp(r'^\d+[\.,]\d{2}$').hasMatch(line)) return true;
    if (line == 'InStock' || line == 'OutOfStock') return true;
    if (RegExp(r'^\d+x$').hasMatch(line)) return true;
    if (RegExp(r'^€\s*\d+').hasMatch(line)) return true;
    if (line.startsWith('Staffelprijzen')) return true;
    if (RegExp(r'p/s$').hasMatch(line)) return true;
    if (RegExp(r'^\d{1,4}$').hasMatch(line)) return true;
    if (line.contains('_wwk_') || line.contains('function') ||
        line.contains('createElement') || line.contains('typeof') ||
        line.contains('document.') || line.contains('.push(') ||
        line.contains('var ') || line.contains('async')) {
      return true;
    }
    if (line == 'CONTACT' || line == 'VERZENDING' || line == 'HOMEPAGE' || line == 'SLUITEN') return true;
    if (RegExp(r'^\d{1,3}[\.,]\d$').hasMatch(line)) return true;
    return false;
  }

  Map<String, double> _extractStaffelprijzen(String text) {
    final result = <String, double>{};
    final matches = RegExp(r'(\d+)x\s*€?\s*(\d+[\.,]\d{2})\s*p/s').allMatches(text);
    for (final m in matches) {
      final qty = m.group(1)!;
      final price = double.tryParse(m.group(2)!.replaceAll(',', '.'));
      if (price != null) result['${qty}x'] = price;
    }
    return result;
  }

  Map<String, String?> _extractSpecs(String text) {
    String? luff, foot, sailArea;
    if (text.contains('Luff') && text.contains('Foot')) {
      final specMatch = RegExp(r'(\d{2,4})\s+(\d{2,4})\s+([\d.,]+)').firstMatch(text);
      if (specMatch != null) {
        luff = '${specMatch.group(1)} cm';
        foot = '${specMatch.group(2)} cm';
        sailArea = '${specMatch.group(3)} m²';
      }
    }
    sailArea ??= _extractSailAreaFromTitle(text);
    return {'luff': luff, 'foot': foot, 'sailArea': sailArea};
  }

  String? _extractSailAreaFromTitle(String text) {
    final match = RegExp(r'(\d+[\.,]\d+)\s*m2').firstMatch(text);
    if (match != null) return '${match.group(1)} m²';
    return null;
  }

  Map<String, String?> _extractSeo(Document doc) {
    String? meta(String attr, String value) {
      final el = doc.querySelector('meta[$attr="$value"]');
      return el?.attributes['content']?.trim();
    }

    final titleEl = doc.querySelector('title');
    final canonicalEl = doc.querySelector('link[rel="canonical"]');

    return {
      'title': titleEl?.text.trim(),
      'description': meta('name', 'description'),
      'keywords': meta('name', 'keywords'),
      'canonical': canonicalEl?.attributes['href']?.trim(),
      'ogImage': meta('property', 'og:image'),
    };
  }

  /// Extracts all product images from the page.
  /// Returns {'main': mainImageUrl, 'extra': [list of extra image URLs]}.
  Map<String, dynamic> _extractProductImages(Document doc, String rawHtml) {
    final artIdEl = doc.querySelector('input[name="winkelwagen"]');
    final artId = artIdEl?.attributes['value'];

    if (artId == null || artId.isEmpty) return {};

    final fullSizeImgs = <String>{};
    String? mainImage;

    final imgPattern = RegExp('webshopartikelen/$artId/([^"\'\\s]+)');
    for (final m in imgPattern.allMatches(rawHtml)) {
      final path = m.group(0)!;
      if (path.contains('/thumbs/')) continue;
      final fullUrl = 'https://ventoz.nl/files/15027/$path';
      mainImage ??= fullUrl;
      fullSizeImgs.add(fullUrl);
    }

    final extra = fullSizeImgs.where((u) => u != mainImage).toList();

    return {
      'main': mainImage,
      'extra': extra,
    };
  }

  // ─── Scrape all with safety ───

  Future<List<CatalogProduct>> scrapeAll({
    void Function(ScrapeProgress)? onProgress,
    bool scrapeImages = false,
  }) async {
    final entries = await fetchSitemapEntries();
    final products = <CatalogProduct>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      onProgress?.call(ScrapeProgress(
        total: entries.length,
        current: i + 1,
        currentProduct: Uri.parse(entry.url).pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? entry.url,
      ));

      final product = await scrapeProductPage(entry.url, entry.imageUrl, scrapeImages: scrapeImages);
      if (product != null) {
        products.add(product);
      }

      if (i < entries.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    return products;
  }

  // ─── Safe sync with anomaly detection ───

  Future<SyncResult> safeSyncToSupabase(List<CatalogProduct> products) async {
    final warnings = <SyncWarning>[];
    final dbCount = await catalogCount();

    if (products.isEmpty) {
      return SyncResult(
        syncedCount: 0,
        aborted: true,
        warnings: [const SyncWarning(
          'Website gaf 0 producten terug. Sync afgebroken om bestaande data te beschermen.',
          SyncWarningLevel.critical,
        )],
      );
    }

    // If we have existing data, check for suspicious drops
    if (dbCount > 10) {
      final dropRatio = products.length / dbCount;
      if (dropRatio < 0.5) {
        return SyncResult(
          syncedCount: 0,
          aborted: true,
          warnings: [SyncWarning(
            'Website geeft ${products.length} producten, database heeft $dbCount. '
            'Daling >50% is verdacht. Sync afgebroken, bestaande data behouden.',
            SyncWarningLevel.critical,
          )],
        );
      }
      if (dropRatio < 0.8) {
        warnings.add(SyncWarning(
          'Website geeft ${products.length} producten (was $dbCount). '
          'Let op: ${dbCount - products.length} producten minder.',
          SyncWarningLevel.warning,
        ));
      }
    }

    final emptyNames = products.where((p) => p.naam.trim().isEmpty).length;
    if (emptyNames > products.length * 0.1) {
      return SyncResult(
        syncedCount: 0,
        aborted: true,
        warnings: [SyncWarning(
          '$emptyNames van ${products.length} producten hebben geen naam. '
          'Websitestructuur mogelijk gewijzigd. Sync afgebroken.',
          SyncWarningLevel.critical,
        )],
      );
    }

    final noPriceNoStock = products.where((p) => p.prijs == null && !p.inStock).length;
    if (noPriceNoStock > products.length * 0.3) {
      warnings.add(SyncWarning(
        '$noPriceNoStock van ${products.length} producten zonder prijs of voorraad.',
        SyncWarningLevel.warning,
      ));
    }

    final count = await _doSync(products);
    return SyncResult(syncedCount: count, warnings: warnings);
  }

  Future<int> _doSync(List<CatalogProduct> products) async {
    int count = 0;
    final syncedUrls = <String>{};

    final imgService = ProductImageService();

    // Fetch existing products to determine which are new vs existing
    final existingUrls = <String>{};
    try {
      final List<dynamic> existing = await _client
          .from('product_catalogus')
          .select('webshop_url');
      for (final row in existing.cast<Map<String, dynamic>>()) {
        final url = row['webshop_url'] as String?;
        if (url != null) existingUrls.add(url);
      }
    } catch (_) {}

    for (final product in products) {
      try {
        final isNew = product.webshopUrl == null || !existingUrls.contains(product.webshopUrl);

        if (isNew) {
          // New product: insert all fields
          final rows = await _client.from('product_catalogus').upsert(
            product.toJson(),
            onConflict: 'webshop_url',
          ).select('id');
          count++;
          if (product.webshopUrl != null) syncedUrls.add(product.webshopUrl!);

          if (rows.isNotEmpty) {
            final pid = rows.first['id'] as int;
            final hasExternal = (product.afbeeldingUrl != null && imgService.isExternalUrl(product.afbeeldingUrl!)) ||
                product.extraAfbeeldingen.any(imgService.isExternalUrl);
            if (hasExternal) {
              final updates = await imgService.migrateProductImages(
                productId: pid,
                mainImageUrl: product.afbeeldingUrl,
                extraImageUrls: product.extraAfbeeldingen,
              );
              if (updates.isNotEmpty) {
                await _client.from('product_catalogus').update(updates).eq('id', pid);
              }
            }
          }
        } else {
          // Existing product: only update price, stock, and timestamps
          final updateData = <String, dynamic>{
            'prijs': product.prijs,
            'in_stock': product.inStock,
            'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
          };
          if (product.staffelprijzen != null) {
            updateData['staffelprijzen'] = product.staffelprijzen;
          }

          await _client.from('product_catalogus')
              .update(updateData)
              .eq('webshop_url', product.webshopUrl!);
          count++;
          syncedUrls.add(product.webshopUrl!);
        }
      } on PostgrestException catch (e) {
        if (kDebugMode) debugPrint('Sync failed for ${product.naam}: ${e.code} ${e.message}');
        try {
          // Fallback: minimal update for existing, full upsert for new
          if (product.webshopUrl != null && existingUrls.contains(product.webshopUrl)) {
            await _client.from('product_catalogus').update({
              'prijs': product.prijs,
              'in_stock': product.inStock,
              'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
            }).eq('webshop_url', product.webshopUrl!);
          } else {
            await _client.from('product_catalogus').upsert(
              product.toJsonMinimal(),
              onConflict: 'webshop_url',
            );
          }
          count++;
          if (product.webshopUrl != null) syncedUrls.add(product.webshopUrl!);
        } on PostgrestException catch (e2) {
          debugPrint('Fallback sync also failed for ${product.naam}: ${e2.code} ${e2.message}');
        }
      }
    }

    // Only mark products as out-of-stock if most upserts succeeded
    if (syncedUrls.length > products.length ~/ 2) {
      try {
        final List<dynamic> allRows = await _client
            .from('product_catalogus')
            .select('id, webshop_url, in_stock');
        for (final row in allRows.cast<Map<String, dynamic>>()) {
          final url = row['webshop_url'] as String?;
          if (url != null && !syncedUrls.contains(url) && row['in_stock'] == true) {
            await _client.from('product_catalogus')
                .update({'in_stock': false})
                .eq('id', row['id'] as int);
          }
        }
      } catch (_) {}
    } else {
      if (kDebugMode) debugPrint('Skipping out-of-stock marking: only ${syncedUrls.length}/${products.length} upserts succeeded');
    }

    return count;
  }

  /// Legacy non-safe sync (still used for direct calls).
  Future<int> syncToSupabase(List<CatalogProduct> products) async {
    return _doSync(products);
  }

  // ─── Fetch & count ───

  Future<List<CatalogProduct>> fetchCatalog({bool includeBlocked = false}) async {
    if (!includeBlocked &&
        _catalogCache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _catalogCache!;
    }

    try {
      var query = _client.from('product_catalogus').select();
      if (!includeBlocked) {
        query = query.or('geblokkeerd.is.null,geblokkeerd.eq.false');
      }
      final List<dynamic> response = await query
          .order('categorie', ascending: true)
          .order('naam', ascending: true);
      final products = response
          .cast<Map<String, dynamic>>()
          .map((json) => CatalogProduct.fromJson(json))
          .toList();

      if (!includeBlocked) {
        _catalogCache = products;
        _cacheTime = DateTime.now();
      }

      return products;
    } on PostgrestException catch (e) {
      throw Exception('Catalogus laden mislukt (${e.code}): ${e.message}');
    }
  }

  void invalidateCatalogCache() {
    _catalogCache = null;
    _cacheTime = null;
  }

  Future<List<CatalogProduct>> fetchBlockedProducts() async {
    try {
      final List<dynamic> response = await _client
          .from('product_catalogus')
          .select()
          .eq('geblokkeerd', true)
          .order('geblokkeerd_op', ascending: false);
      return response
          .cast<Map<String, dynamic>>()
          .map((json) => CatalogProduct.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Geblokkeerde producten laden mislukt (${e.code}): ${e.message}');
    }
  }

  Future<void> toggleBlockProduct(int id, bool block, {String? byEmail}) async {
    final data = <String, dynamic>{
      'geblokkeerd': block,
      'geblokkeerd_door': block ? byEmail : null,
      'geblokkeerd_op': block ? DateTime.now().toUtc().toIso8601String() : null,
    };
    await _client.from('product_catalogus').update(data).eq('id', id);
    invalidateCatalogCache();
  }

  Future<void> bulkBlockProducts(List<int> ids, bool block, {String? byEmail}) async {
    for (final id in ids) {
      await toggleBlockProduct(id, block, byEmail: byEmail);
    }
  }

  Future<CatalogProduct> addManualProduct({
    required String naam,
    String? categorie,
    double? prijs,
    String? beschrijving,
    String? afbeeldingUrl,
    String? artikelnummer,
  }) async {
    final data = <String, dynamic>{
      'naam': naam,
      'in_stock': true,
      'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
    };
    if (categorie != null) data['categorie'] = categorie;
    if (prijs != null) data['prijs'] = prijs;
    if (beschrijving != null) data['beschrijving'] = beschrijving;
    if (afbeeldingUrl != null) data['afbeelding_url'] = afbeeldingUrl;
    if (artikelnummer != null) data['artikelnummer'] = artikelnummer;
    final result = await _client.from('product_catalogus').insert(data).select().single();
    invalidateCatalogCache();
    return CatalogProduct.fromJson(result);
  }

  Future<void> updateProductOverrides(int id, Map<String, dynamic> overrides) async {
    final allowed = <String, dynamic>{};
    const overrideKeys = {'naam_override', 'beschrijving_override', 'prijs_override', 'afbeelding_url_override', 'extra_afbeeldingen', 'gewicht', 'ean_code'};
    for (final entry in overrides.entries) {
      if (overrideKeys.contains(entry.key)) {
        allowed[entry.key] = entry.value;
      }
    }
    if (allowed.isEmpty) return;
    await _client.from('product_catalogus').update(allowed).eq('id', id);
  }

  Future<int> catalogCount() async {
    try {
      final response = await _client.from('product_catalogus').select('id');
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ─── Freshness check ───

  Future<StaleCatalogInfo?> checkFreshness({int maxAgeDays = 7}) async {
    try {
      DateTime? lastSync;
      int dbCount = 0;
      try {
        final List<dynamic> rows = await _client
            .from('product_catalogus')
            .select('laatst_bijgewerkt')
            .order('laatst_bijgewerkt', ascending: false)
            .limit(1);
        if (rows.isNotEmpty) {
          lastSync = DateTime.tryParse(
              (rows.first as Map<String, dynamic>)['laatst_bijgewerkt'] as String? ?? '');
        }
        dbCount = await catalogCount();
      } catch (_) {}

      if (dbCount == 0) {
        return StaleCatalogInfo(sitemapCount: 0, dbCount: 0, lastSync: null, countMismatch: false, isOld: true);
      }

      final isOld = lastSync == null ||
          DateTime.now().toUtc().difference(lastSync.toUtc()).inDays >= maxAgeDays;
      if (!isOld) return null;

      final sitemapEntries = await fetchSitemapEntries();
      final diff = (sitemapEntries.length - dbCount).abs();
      final countMismatch = diff > 3;

      return StaleCatalogInfo(
        sitemapCount: sitemapEntries.length, dbCount: dbCount,
        lastSync: lastSync, countMismatch: countMismatch, isOld: isOld,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Background sync (safe) ───

  Future<SyncResult> backgroundSyncSafe() async {
    try {
      final response = await http.get(Uri.parse(_sitemapUrl));
      if (response.statusCode != 200) {
        return SyncResult(
          syncedCount: 0, aborted: true,
          warnings: [SyncWarning(
            'Website niet bereikbaar (HTTP ${response.statusCode}). Bestaande data behouden.',
            SyncWarningLevel.critical,
          )],
        );
      }
    } catch (e) {
      return SyncResult(
        syncedCount: 0, aborted: true,
        warnings: [SyncWarning(
          'Website niet bereikbaar: $e. Bestaande data behouden.',
          SyncWarningLevel.critical,
        )],
      );
    }

    try {
      final products = await scrapeAll();
      final result = await safeSyncToSupabase(products);
      if (!result.aborted) {
        await translateAllProducts();
      }
      return result;
    } catch (e) {
      return SyncResult(
        syncedCount: 0, aborted: true,
        warnings: [SyncWarning(
          'Onverwachte fout bij synchronisatie: $e. Bestaande data behouden.',
          SyncWarningLevel.critical,
        )],
      );
    }
  }

  /// Legacy background sync.
  Future<int> backgroundSync() async {
    try {
      final products = await scrapeAll();
      final count = await syncToSupabase(products);
      await translateAllProducts();
      return count;
    } catch (_) {
      return -1;
    }
  }

  Future<int> ensureTranslations() async {
    try {
      return await translateAllProducts();
    } catch (_) {
      return -1;
    }
  }

  // ─── Translation: all 23 EU languages ───

  /// Translates products that are missing translations for any of the 23
  /// target languages. Checks a sample of 3 languages spread across old
  /// (de, en) and new (sv) to detect which products need work.
  /// Set [forceAll] to true to retranslate every product regardless.
  Future<int> translateAllProducts({
    void Function(int current, int total)? onProgress,
    bool forceAll = false,
  }) async {
    final translator = TranslateService();
    final targets = TranslateService.translationTargets;
    int translated = 0;

    final selectCols = [
      'id', 'naam', 'beschrijving',
      ...targets.map((l) => 'naam_$l'),
    ];
    final List<dynamic> rows = await _client
        .from('product_catalogus')
        .select(selectCols.join(', '))
        .order('id', ascending: true);

    final needsWork = <Map<String, dynamic>>[];
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final naam = (row['naam'] as String?) ?? '';
      if (naam.isEmpty) continue;

      if (forceAll) {
        needsWork.add(row);
        continue;
      }

      // Check if any target language is missing a translation
      for (final lang in targets) {
        final val = row['naam_$lang'];
        if (val == null || (val as String).isEmpty) {
          needsWork.add(row);
          break;
        }
      }
    }

    for (var i = 0; i < needsWork.length; i++) {
      final row = needsWork[i];
      final id = row['id'] as int;
      final naam = row['naam'] as String;
      final beschrijving = row['beschrijving'] as String?;

      onProgress?.call(i + 1, needsWork.length);

      final updates = <String, dynamic>{};

      for (final lang in targets) {
        // Skip languages that already have a translation (unless forcing)
        if (!forceAll) {
          final existing = row['naam_$lang'];
          if (existing != null && (existing as String).isNotEmpty) continue;
        }

        final translatedName = await translator.translate(naam, targetLang: lang);
        updates['naam_$lang'] = translatedName;
        await Future.delayed(const Duration(milliseconds: 60));
      }

      if (beschrijving != null && beschrijving.isNotEmpty) {
        for (final lang in targets) {
          if (!forceAll) {
            // Only translate description if name was also missing for this lang
            if (!updates.containsKey('naam_$lang')) continue;
          }
          final translatedDesc = await translator.translate(beschrijving, targetLang: lang);
          updates['beschrijving_$lang'] = translatedDesc;
          await Future.delayed(const Duration(milliseconds: 60));
        }
      }

      if (updates.isNotEmpty) {
        try {
          await _client.from('product_catalogus').update(updates).eq('id', id);
          translated++;
        } on PostgrestException catch (_) {}
      }
    }
    return translated;
  }

  /// Re-translates a specific product whose NL text has changed.
  Future<void> retranslateProduct(int productId, String naam, String? beschrijving) async {
    final translator = TranslateService();
    final targets = TranslateService.translationTargets;
    final updates = <String, dynamic>{};

    for (final lang in targets) {
      updates['naam_$lang'] = await translator.translate(naam, targetLang: lang);
      await Future.delayed(const Duration(milliseconds: 60));
    }

    if (beschrijving != null && beschrijving.isNotEmpty) {
      for (final lang in targets) {
        updates['beschrijving_$lang'] = await translator.translate(beschrijving, targetLang: lang);
        await Future.delayed(const Duration(milliseconds: 60));
      }
    }

    try {
      await _client.from('product_catalogus').update(updates).eq('id', productId);
    } on PostgrestException catch (_) {}
  }

  /// After a sync, detect products whose NL text changed and retranslate them.
  Future<int> retranslateChanged({
    void Function(int current, int total)? onProgress,
  }) async {
    final translator = TranslateService();
    final targets = TranslateService.translationTargets;
    int retranslated = 0;

    // We detect changes by checking if naam_de exists but was based on old NL text.
    // Simple heuristic: re-translate products that have naam_de but whose
    // naam_de was set > 1 day before the current laatst_bijgewerkt.
    // More robust: we just retranslate all products synced in the last hour
    // that already had translations.
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();
    final List<dynamic> recentRows = await _client
        .from('product_catalogus')
        .select('id, naam, beschrijving, naam_de')
        .gte('laatst_bijgewerkt', cutoff)
        .not('naam_de', 'is', 'null')
        .order('id', ascending: true);

    final rows = recentRows.cast<Map<String, dynamic>>();
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final id = row['id'] as int;
      final naam = (row['naam'] as String?) ?? '';
      final beschrijving = row['beschrijving'] as String?;
      if (naam.isEmpty) continue;

      onProgress?.call(i + 1, rows.length);

      final updates = <String, dynamic>{};
      for (final lang in targets) {
        updates['naam_$lang'] = await translator.translate(naam, targetLang: lang);
        await Future.delayed(const Duration(milliseconds: 60));
      }
      if (beschrijving != null && beschrijving.isNotEmpty) {
        for (final lang in targets) {
          updates['beschrijving_$lang'] = await translator.translate(beschrijving, targetLang: lang);
          await Future.delayed(const Duration(milliseconds: 60));
        }
      }

      try {
        await _client.from('product_catalogus').update(updates).eq('id', id);
        retranslated++;
      } on PostgrestException catch (_) {}
    }
    return retranslated;
  }

  /// Legacy compat
  Future<int> translateUntranslated({
    void Function(int current, int total)? onProgress,
  }) async {
    return translateAllProducts(onProgress: onProgress);
  }
}

class StaleCatalogInfo {
  final int sitemapCount;
  final int dbCount;
  final DateTime? lastSync;
  final bool countMismatch;
  final bool isOld;
  const StaleCatalogInfo({
    required this.sitemapCount, required this.dbCount,
    required this.lastSync, required this.countMismatch, required this.isOld,
  });
}
