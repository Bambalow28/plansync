import 'dart:typed_data';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/category.dart';
import '../models/itinerary_item.dart';
import '../models/trip.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Renders a [Trip] as a PDF that mirrors the app's dark timeline UI — same
/// fonts and category colors, cards laid out like [_EventCard] — for sharing
/// outside the app. Fully offline: fonts are the bundled app fonts, no
/// network font fetch (this app has no server dependency).
class ItineraryPdf {
  ItineraryPdf._();

  static PdfColor _c(Color c) => PdfColor(c.r, c.g, c.b, c.a);

  /// Alpha-blends [color] over [background] and returns an opaque [PdfColor].
  /// The pdf package's fill painter writes RGB only and drops the alpha
  /// channel entirely — a translucent decoration color like
  /// `category.withValues(alpha: 0.15)` renders fully OPAQUE at that hue, not
  /// as a light tint. That made the category pill's text (painted in the
  /// same opaque hue) invisible against its own background. Pre-blending
  /// here bakes the intended tint into a genuinely opaque color instead.
  static PdfColor _tint(Color color, {required Color over}) => _c(Color.alphaBlend(color, over));

  static Future<Uint8List> buildBytes(Trip trip) async {
    final f = await _Fonts.load();
    final doc = pw.Document();

    final bg = _c(AppColors.background);
    final textSecondary = _tint(AppColors.textSecondary, over: AppColors.background);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
          theme: pw.ThemeData.withFont(base: f.regular, bold: f.semiBold),
          buildBackground: (_) =>
              pw.FullPage(ignoreMargins: true, child: pw.Container(color: bg)),
        ),
        build: (context) => [
          _header(trip, f),
          pw.SizedBox(height: 18),
          for (final day in trip.days) ..._daySection(trip, day, f),
          pw.SizedBox(height: 18),
          pw.Text(
            'Shared from PlanSync',
            style: pw.TextStyle(
              font: f.mono,
              fontSize: 8,
              color: textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(Trip trip, _Fonts f) {
    final coverColors = tripCovers[trip.cover]!;
    // Text/tints in the header sit on the cover gradient, not a flat surface —
    // blend against its midpoint as a reasonable stand-in for "the gradient".
    final headerBg = Color.lerp(coverColors[0], coverColors[1], 0.5)!;
    final textSecondary = _tint(AppColors.textSecondary, over: headerBg);
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_c(coverColors[0]), _c(coverColors[1])],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            trip.name,
            style: pw.TextStyle(
              font: f.serifBold,
              fontSize: 24,
              color: PdfColors.white,
            ),
          ),
          if (trip.hasDestination) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              trip.destinationLabel,
              style: pw.TextStyle(
                font: f.regular,
                fontSize: 12,
                color: textSecondary,
              ),
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Text(
            shortRange(trip.startDate, trip.endDate).toUpperCase(),
            style: pw.TextStyle(
              font: f.mono,
              fontSize: 9,
              color: textSecondary,
              letterSpacing: 1,
            ),
          ),
          if (trip.budget > 0 || trip.spent > 0) ...[
            pw.SizedBox(height: 14),
            _budgetBar(trip, f, headerBg),
          ],
        ],
      ),
    );
  }

  static pw.Widget _budgetBar(Trip trip, _Fonts f, Color background) {
    final spent = trip.spent;
    final hasBudget = trip.budget > 0;
    final ratio = hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && spent > trip.budget;
    final barColor = _c(over ? AppColors.warning : AppColors.accent);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${money(spent, trip.currency)} spent',
              style: pw.TextStyle(
                font: f.semiBold,
                fontSize: 11,
                color: PdfColors.white,
              ),
            ),
            pw.Text(
              hasBudget
                  ? (over
                        ? '${money(spent - trip.budget, trip.currency)} over'
                        : '${money(trip.remaining, trip.currency)} left')
                  : 'No budget',
              style: pw.TextStyle(
                font: f.mono,
                fontSize: 9,
                color: barColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        if (hasBudget) ...[
          pw.SizedBox(height: 6),
          pw.LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: _tint(Colors.black.withValues(alpha: 0.35), over: background),
            valueColor: barColor,
          ),
        ],
      ],
    );
  }

  static List<pw.Widget> _daySection(Trip trip, DateTime day, _Fonts f) {
    final items = trip.itemsOn(day);
    if (items.isEmpty) return [];
    return [
      pw.Text(
        fullDate(day).toUpperCase(),
        style: pw.TextStyle(
          font: f.mono,
          fontSize: 10,
          color: _c(AppColors.accent),
          letterSpacing: 1.5,
        ),
      ),
      pw.SizedBox(height: 8),
      for (final it in items) _card(it, day, trip.currency, f),
      pw.SizedBox(height: 10),
    ];
  }

  static pw.Widget _card(
    ItineraryItem item,
    DateTime day,
    String currency,
    _Fonts f,
  ) {
    final s = styleOf(item.category);
    final catColor = _c(s.color);
    final range = item.displayTimeRangeLabel(day);
    final rangeLabel = range.isNotEmpty
        ? range
        : (item.start != null ? item.displayStartLabel(day) : '');
    final flightLine = item.isFlight ? _flightLine(item) : '';
    final textSecondary = _tint(AppColors.textSecondary, over: AppColors.surface);
    final textMuted = _tint(AppColors.textMuted, over: AppColors.surface);

    // A colored left edge makes the plan's category read at a glance, same
    // idea as the app's category-colored spine. The pdf package's Border
    // can't mix a borderRadius with non-uniform sides, so the accent is a
    // separate overlay clipped to the same rounded corners instead.
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: _c(AppColors.surface),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
          color: _tint(Colors.white.withValues(alpha: 0.08), over: AppColors.surface),
          width: 0.6,
        ),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 12,
        verticalRadius: 12,
        child: pw.Stack(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _tint(s.color.withValues(alpha: 0.15), over: AppColors.surface),
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        // Full category word, not an abbreviation. No icon/emoji
                        // glyph: the app's Material icon font isn't renderable
                        // here (CFF/OTF outlines, the pdf package only reads
                        // glyf), and the bundled text fonts have no emoji
                        // glyphs either (confirmed — they silently drop them).
                        child: pw.Text(
                          s.label.toUpperCase(),
                          style: pw.TextStyle(
                            font: f.mono,
                            fontSize: 8,
                            color: catColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      pw.Spacer(),
                      if (item.cost > 0)
                        pw.Text(
                          money(item.cost, currency),
                          style: pw.TextStyle(
                            font: f.mono,
                            fontSize: 9,
                            color: textSecondary,
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    item.title,
                    style: pw.TextStyle(
                      font: f.semiBold,
                      fontSize: 13,
                      color: PdfColors.white,
                    ),
                  ),
                  if (rangeLabel.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      rangeLabel,
                      style: pw.TextStyle(
                        font: f.mono,
                        fontSize: 8,
                        color: textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                  if (flightLine.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      flightLine,
                      style: pw.TextStyle(
                        font: f.regular,
                        fontSize: 9,
                        color: textSecondary,
                      ),
                    ),
                  ] else if (item.hasLocation) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      item.locationLabel,
                      style: pw.TextStyle(
                        font: f.regular,
                        fontSize: 9,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: pw.Container(width: 4, color: catColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Same route-line idea as the app's event card, but ASCII-only — PDF text
  /// rendering doesn't get Flutter's automatic glyph-fallback, so unicode
  /// arrows risk showing as a missing-glyph box in fonts that lack them.
  static String _flightLine(ItineraryItem item) {
    String code(String? iata, {required bool arrival}) {
      final c = iata?.trim();
      if (c != null && c.isNotEmpty) return c.toUpperCase();
      final p = arrival ? item.arrivalLocation : item.location;
      return p?.label.split(',').first.trim() ?? '';
    }

    final from = code(item.departureCode, arrival: false);
    final to = code(item.arrivalCode, arrival: true);
    final route = (from.isNotEmpty || to.isNotEmpty) ? '$from to $to' : '';
    final fc = item.flightCode?.trim();
    if (fc != null && fc.isNotEmpty && route.isNotEmpty) return '$fc · $route';
    return fc != null && fc.isNotEmpty ? fc : route;
  }
}

/// Loads the app's bundled fonts as PDF fonts once per build call.
class _Fonts {
  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font serifBold;
  final pw.Font mono;

  const _Fonts({
    required this.regular,
    required this.semiBold,
    required this.serifBold,
    required this.mono,
  });

  static Future<_Fonts> load() async {
    Future<pw.Font> ttf(String asset) async =>
        pw.Font.ttf(await rootBundle.load(asset));
    final results = await Future.wait([
      ttf('assets/fonts/Inter-Regular.ttf'),
      ttf('assets/fonts/Inter-SemiBold.ttf'),
      ttf('assets/fonts/CrimsonText-Bold.ttf'),
      ttf('assets/fonts/AnonymousPro-Regular.ttf'),
    ]);
    return _Fonts(
      regular: results[0],
      semiBold: results[1],
      serifBold: results[2],
      mono: results[3],
    );
  }
}
