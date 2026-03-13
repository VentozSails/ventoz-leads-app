import 'dart:async';
import 'package:flutter/material.dart';
import '../services/postcode_service.dart';

/// Reusable address form fields with automatic postcode lookup for NL/BE.
class AddressFormFields extends StatefulWidget {
  final TextEditingController postcodeCtrl;
  final TextEditingController huisnummerCtrl;
  final TextEditingController straatCtrl;
  final TextEditingController woonplaatsCtrl;
  final String landCode;
  final String Function(String key) t;

  const AddressFormFields({
    super.key,
    required this.postcodeCtrl,
    required this.huisnummerCtrl,
    required this.straatCtrl,
    required this.woonplaatsCtrl,
    required this.landCode,
    required this.t,
  });

  @override
  State<AddressFormFields> createState() => _AddressFormFieldsState();
}

class _AddressFormFieldsState extends State<AddressFormFields> {
  Timer? _debounce;
  bool _looking = false;
  bool _found = false;
  String? _lookupError;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPostcodeOrHuisnummerChanged() {
    _debounce?.cancel();
    setState(() { _found = false; _lookupError = null; });

    final pc = widget.postcodeCtrl.text.trim();
    final nr = widget.huisnummerCtrl.text.trim();
    if (pc.isEmpty || nr.isEmpty) return;

    final land = widget.landCode.toUpperCase();
    if (land == 'NL' && !PostcodeService.isValidNlPostcode(pc)) return;
    if (land == 'BE' && !PostcodeService.isValidBePostcode(pc)) return;
    if (nr.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 500), () => _doLookup(pc, nr));
  }

  Future<void> _doLookup(String postcode, String huisnummer) async {
    if (!mounted) return;
    setState(() { _looking = true; _lookupError = null; });

    final result = await PostcodeService.lookup(postcode, huisnummer);

    if (!mounted) return;
    if (result != null) {
      widget.straatCtrl.text = result.straat;
      widget.woonplaatsCtrl.text = result.plaats;
      setState(() { _looking = false; _found = true; });
    } else {
      setState(() { _looking = false; _lookupError = widget.t('adres_niet_gevonden'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNlBe = ['NL', 'BE'].contains(widget.landCode.toUpperCase());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isNlBe) ...[
          Row(children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: widget.postcodeCtrl,
                decoration: InputDecoration(
                  labelText: widget.t('postcode'),
                  isDense: true,
                  hintText: widget.landCode.toUpperCase() == 'NL' ? '1234 AB' : '1000',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.isEmpty) return widget.t('verplicht');
                  final cc = widget.landCode.toUpperCase();
                  if (cc == 'NL' && !RegExp(r'^\d{4}\s?[A-Za-z]{2}$').hasMatch(v.trim())) {
                    return 'Formaat: 1234 AB';
                  }
                  if (cc == 'BE' && !RegExp(r'^\d{4}$').hasMatch(v.trim())) {
                    return 'Formaat: 1000';
                  }
                  return null;
                },
                onChanged: (_) => _onPostcodeOrHuisnummerChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: widget.huisnummerCtrl,
                decoration: InputDecoration(
                  labelText: widget.t('huisnummer'),
                  isDense: true,
                  suffixIcon: _looking
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : _found
                          ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20)
                          : null,
                ),
                keyboardType: TextInputType.text,
                validator: (v) => v == null || v.isEmpty ? widget.t('verplicht') : null,
                onChanged: (_) => _onPostcodeOrHuisnummerChanged(),
              ),
            ),
          ]),
          if (_lookupError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_lookupError!, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: widget.straatCtrl,
          decoration: InputDecoration(
            labelText: isNlBe ? widget.t('straat') : widget.t('adres'),
            isDense: true,
          ),
          validator: (v) => v == null || v.isEmpty ? widget.t('verplicht') : null,
        ),
        const SizedBox(height: 12),
        if (!isNlBe) ...[
          Row(children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: widget.postcodeCtrl,
                decoration: InputDecoration(labelText: widget.t('postcode'), isDense: true),
                validator: (v) => v == null || v.isEmpty ? widget.t('verplicht') : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: widget.woonplaatsCtrl,
                decoration: InputDecoration(labelText: widget.t('woonplaats'), isDense: true),
                validator: (v) => v == null || v.isEmpty ? widget.t('verplicht') : null,
              ),
            ),
          ]),
        ] else ...[
          TextFormField(
            controller: widget.woonplaatsCtrl,
            decoration: InputDecoration(labelText: widget.t('woonplaats'), isDense: true),
            validator: (v) => v == null || v.isEmpty ? widget.t('verplicht') : null,
          ),
        ],
      ],
    );
  }
}
