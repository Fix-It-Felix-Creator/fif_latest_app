import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/customer.dart';
import '../models/pricing_item.dart';
import '../models/quote_model.dart';
import '../models/staff.dart';
import '../models/user_details_model.dart';

/// Renders a quote as a single-page PDF matching the layout in
/// `screenshots/pdf.png` — big "QUOTE" header, business name + phone
/// on the right, quote meta + customer block, line-items table,
/// subtotal/VAT/total stack, then a Notes section. Designed to work
/// offline; consumes only data already on the [Quote] and the
/// signed-in [UserDetailsModel].
class QuotePdfService {
  static const _ink = PdfColor.fromInt(0xFF111111);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFE5E7EB);

  Future<Uint8List> build({
    required Quote quote,
    UserDetailsModel? user,
  }) async {
    final doc = pw.Document(
      title: 'Quote ${quote.reference}',
      author: _businessName(user),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        build: (ctx) => [
          _header(quote, user),
          pw.SizedBox(height: 28),
          _meta(quote),
          pw.SizedBox(height: 20),
          _divider(),
          pw.SizedBox(height: 16),
          _itemsTable(quote),
          pw.SizedBox(height: 16),
          _totals(quote),
          pw.SizedBox(height: 24),
          _divider(),
          pw.SizedBox(height: 14),
          _notes(),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(Quote q, UserDetailsModel? u) {
    final name = _businessName(u);
    final phone = _businessPhone(u);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            'QUOTE',
            style: pw.TextStyle(
              fontSize: 36,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (name.isNotEmpty)
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            if (phone.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                phone,
                style: pw.TextStyle(fontSize: 11, color: _ink),
              ),
            ],
          ],
        ),
      ],
    );
  }

  pw.Widget _meta(Quote q) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _labelLine('Quote number', q.reference.isEmpty ? '—' : q.reference),
        pw.SizedBox(height: 12),
        _labelLine('Issued', _fmtDate(q.date)),
        pw.SizedBox(height: 18),
        _customerBlock(q.customer),
      ],
    );
  }

  pw.Widget _labelLine(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, color: _ink)),
      ],
    );
  }

  pw.Widget _customerBlock(Customer? customer) {
    if (customer == null) {
      return _labelLine('For', '—');
    }
    final lines = _customerAddressLines(customer);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'For',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 4),
        if (customer.name.isNotEmpty)
          pw.Text(
            customer.name,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              line,
              style: pw.TextStyle(fontSize: 11, color: _ink),
            ),
          ),
      ],
    );
  }

  pw.Widget _itemsTable(Quote q) {
    final rows = _flattenLines(q);
    return pw.Column(
      children: [
        // Header row
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.Text(
                  'Item',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              _colHead('Qty', flex: 1, align: pw.TextAlign.right),
              _colHead('Unit Price', flex: 2, align: pw.TextAlign.right),
              _colHead('Total', flex: 2, align: pw.TextAlign.right),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) pw.Container(height: 0.5, color: _line),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Text(
                    rows[i].name,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ),
                _cellRight(rows[i].qty.toString(), flex: 1),
                _cellRight(_fmtMoney(rows[i].unitPrice), flex: 2),
                _cellRight(_fmtMoney(rows[i].total), flex: 2),
              ],
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _colHead(String s, {required int flex, pw.TextAlign? align}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        s,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  pw.Widget _cellRight(String s, {required int flex}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        s,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(fontSize: 11, color: _ink),
      ),
    );
  }

  pw.Widget _totals(Quote q) {
    final subtotal = _subtotal(q);
    return pw.Row(
      children: [
        pw.Spacer(flex: 5),
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            children: [
              _totalsRow('Subtotal', _fmtMoney(subtotal)),
              pw.SizedBox(height: 6),
              _totalsRow('VAT', _fmtMoney(0)),
              pw.SizedBox(height: 8),
              _totalsRow(
                'Total',
                _fmtMoney(subtotal),
                bold: true,
                fontSize: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalsRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 11,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _ink,
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: _ink,
          ),
        ),
      ],
    );
  }

  pw.Widget _notes() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'No additional notes',
          style: pw.TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  pw.Widget _divider() => pw.Container(height: 0.7, color: _line);

  // ─── Header / footer helpers ─────────────────────────────────────

  String _businessName(UserDetailsModel? u) {
    if (u == null) return '';
    final company = u.companyDetails;
    if (company != null && company.companyName.trim().isNotEmpty) {
      return company.companyName.trim();
    }
    if ((u.businessName ?? '').trim().isNotEmpty) {
      return u.businessName!.trim();
    }
    final full = [u.firstName ?? '', u.lastName ?? '']
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    return full;
  }

  String _businessPhone(UserDetailsModel? u) {
    if (u == null) return '';
    final landline = u.companyDetails?.companyLandline?.trim() ?? '';
    if (landline.isNotEmpty) return landline;
    return u.phoneNumber.trim();
  }

  // ─── Computation helpers ─────────────────────────────────────────

  List<_PdfLine> _flattenLines(Quote q) {
    final out = <_PdfLine>[];
    for (final s in q.staff) {
      final who = s.staff.name.isEmpty ? 'Labour' : s.staff.name;
      out.add(_PdfLine(
        name: '$who — ${s.rateType.label} rate',
        qty: s.quantity,
        unitPrice: s.rate,
        total: s.lineTotal,
      ));
    }
    for (final l in q.lines) {
      out.add(_PdfLine(
        name: l.item.name.isEmpty
            ? (l.kind == PricingKind.material ? 'Material' : 'Service')
            : l.item.name,
        qty: l.quantity,
        unitPrice: l.rate + l.unitMarkup,
        total: l.lineTotal,
      ));
    }
    return out;
  }

  double _subtotal(Quote q) {
    double sum = 0;
    for (final l in q.lines) {
      sum += l.lineTotal;
    }
    for (final s in q.staff) {
      sum += s.lineTotal;
    }
    return sum;
  }

  String _fmtMoney(double v) => '£${v.toStringAsFixed(2)}';

  String _fmtDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  List<String> _customerAddressLines(Customer c) {
    final parts = <String>[];
    if (c.addressLine1.isNotEmpty) parts.add(c.addressLine1);
    if ((c.addressLine2 ?? '').isNotEmpty) parts.add(c.addressLine2!);
    final cityCounty = [c.city, c.county ?? ''].where((s) => s.isNotEmpty);
    final lower = [
      ...cityCounty,
      if (c.postcode.isNotEmpty) c.postcode,
    ].join(', ');
    if (lower.isNotEmpty) parts.add(lower);
    return parts;
  }
}

class _PdfLine {
  _PdfLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });
  final String name;
  final int qty;
  final double unitPrice;
  final double total;
}
