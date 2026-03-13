import '../models/catalog_product.dart';
import 'user_service.dart';
import 'vat_service.dart';

/// All catalog prices (prijs, staffelprijzen) are INCLUSIVE of 21% NL VAT.
const double _sellerVatRate = 21.0;

class PriceBreakdown {
  /// Original catalog price (incl. 21% NL BTW)
  final double catalogPriceInclVat;

  /// Unit price excl. VAT (after stripping seller VAT)
  final double unitPriceExclVat;

  /// After quantity discount (staffelprijs), excl. VAT
  final double afterQuantityDiscountExcl;

  /// User discount percentage applied
  final double discountPercentage;

  /// After user discount, excl. VAT
  final double afterDiscountExcl;

  /// Applicable VAT rate for the buyer
  final double vatRate;

  /// VAT amount on afterDiscountExcl
  final double vatAmount;

  /// Final price incl. buyer's VAT
  final double totalInclVat;

  /// Final price excl. VAT
  final double totalExclVat;

  final bool reverseCharge;
  final bool btwVerlegd;
  final String buyerCountry;
  final String? quantityLabel;

  const PriceBreakdown({
    required this.catalogPriceInclVat,
    required this.unitPriceExclVat,
    required this.afterQuantityDiscountExcl,
    required this.discountPercentage,
    required this.afterDiscountExcl,
    required this.vatRate,
    required this.vatAmount,
    required this.totalInclVat,
    required this.totalExclVat,
    required this.reverseCharge,
    this.btwVerlegd = false,
    this.buyerCountry = 'NL',
    this.quantityLabel,
  });

  double get savingsAmount => unitPriceExclVat - afterDiscountExcl;

  String get btwOmschrijving {
    if (btwVerlegd) return 'BTW verlegd (intracommunautaire levering)';
    if (vatRate == 0 && !reverseCharge) return 'Geen BTW (buiten EU)';
    return 'BTW ${vatRate.toStringAsFixed(1)}% ($buyerCountry)';
  }
}

class PricingService {
  /// Strip 21% NL VAT from a catalog price to get the net price.
  static double exclVat(double priceInclVat) {
    return priceInclVat / (1 + _sellerVatRate / 100);
  }

  /// Calculate full price breakdown.
  ///
  /// All product prices are treated as incl. 21% NL BTW.
  static PriceBreakdown calculate({
    required CatalogProduct product,
    required AppUser user,
    int quantity = 1,
    String sellerCountry = 'NL',
  }) {
    final catalogPrice = product.prijs ?? 0;

    // 1. Strip seller VAT to get net base price
    final basePriceExcl = exclVat(catalogPrice);

    // 2. Quantity discount (staffelprijzen — also incl. VAT)
    double unitPriceInclVat = catalogPrice;
    String? qtyLabel;
    if (product.staffelprijzen != null && product.staffelprijzen!.isNotEmpty) {
      final sorted = product.staffelprijzen!.entries.toList()
        ..sort((a, b) {
          final aq = int.tryParse(a.key.replaceAll('x', '')) ?? 0;
          final bq = int.tryParse(b.key.replaceAll('x', '')) ?? 0;
          return bq.compareTo(aq);
        });
      for (final entry in sorted) {
        final minQty = int.tryParse(entry.key.replaceAll('x', '')) ?? 0;
        if (quantity >= minQty && minQty > 0) {
          unitPriceInclVat = entry.value;
          qtyLabel = entry.key;
          break;
        }
      }
    }
    final afterQtyExcl = exclVat(unitPriceInclVat);

    // 3. User discount (highest of permanent / temporary)
    final discountPct = user.effectiveKorting;
    final afterDiscountExcl = discountPct > 0
        ? afterQtyExcl * (1 - discountPct / 100)
        : afterQtyExcl;

    // 4. VAT calculation based on buyer country
    final vatInfo = _calculateVat(user: user, sellerCountry: sellerCountry);
    final vatAmount = afterDiscountExcl * (vatInfo.rate / 100);

    return PriceBreakdown(
      catalogPriceInclVat: catalogPrice,
      unitPriceExclVat: basePriceExcl,
      afterQuantityDiscountExcl: afterQtyExcl,
      discountPercentage: discountPct,
      afterDiscountExcl: afterDiscountExcl,
      vatRate: vatInfo.rate,
      vatAmount: vatAmount,
      totalInclVat: afterDiscountExcl + vatAmount,
      totalExclVat: afterDiscountExcl,
      reverseCharge: vatInfo.reverseCharge,
      btwVerlegd: vatInfo.reverseCharge,
      buyerCountry: user.landCode.toUpperCase(),
      quantityLabel: qtyLabel,
    );
  }

  static _VatCalc _calculateVat({
    required AppUser user,
    required String sellerCountry,
  }) {
    final buyerCountry = user.landCode.toUpperCase();
    final isEu = VatService.isEuCountry(buyerCountry);

    if (!isEu) {
      return _VatCalc(rate: 0, reverseCharge: false);
    }

    if (user.isBedrijf && user.btwGevalideerd && buyerCountry != sellerCountry) {
      return _VatCalc(rate: 0, reverseCharge: true);
    }

    if (buyerCountry == sellerCountry) {
      return _VatCalc(rate: VatService.getVatRate(sellerCountry), reverseCharge: false);
    }

    return _VatCalc(rate: VatService.getVatRate(buyerCountry), reverseCharge: false);
  }

  static String formatEuro(double amount) {
    final str = amount.toStringAsFixed(2).replaceAll('.', ',');
    return '€ $str';
  }
}

class _VatCalc {
  final double rate;
  final bool reverseCharge;
  const _VatCalc({required this.rate, required this.reverseCharge});
}
