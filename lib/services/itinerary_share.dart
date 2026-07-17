import 'dart:io';
import 'dart:ui' show Rect;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip.dart';
import '../utils/format.dart';
import 'itinerary_pdf.dart';

/// Builds a plain-text itinerary for a trip and opens the OS share sheet.
/// Documents/attachments are intentionally excluded.
class ItineraryShare {
  ItineraryShare._();

  /// Renders the shareable text for [trip] (no attachments).
  static String buildText(Trip trip) {
    final b = StringBuffer();
    final flag = trip.destination != null ? flagEmoji(trip.destination!.countryCode) : '';

    b.writeln('${flag.isNotEmpty ? '$flag ' : ''}${trip.name}');
    if (trip.hasDestination) b.writeln(trip.destinationLabel);
    b.writeln(shortRange(trip.startDate, trip.endDate));

    // Budget summary.
    if (trip.budget > 0) {
      b.writeln('Budget: ${money(trip.spent, trip.currency)} of ${money(trip.budget, trip.currency)}');
    } else if (trip.spent > 0) {
      b.writeln('Spent: ${money(trip.spent, trip.currency)}');
    }

    for (final day in trip.days) {
      final items = trip.itemsOn(day);
      if (items.isEmpty) continue;
      b.writeln('');
      b.writeln(fullDate(day).toUpperCase());
      for (final it in items) {
        final range = it.displayTimeRangeLabel(day);
        final time = range.isNotEmpty ? range : (it.start != null ? it.displayStartLabel(day) : 'Anytime');
        final parts = <String>['  • $time — ${it.title}'];
        b.writeln(parts.join());
        if (it.hasLocation) b.writeln('      ${it.locationLabel}');
        if (it.cost > 0) b.writeln('      ${money(it.cost, trip.currency)}');
      }
    }

    b.writeln('');
    b.writeln('Shared from PlanSync');
    return b.toString().trimRight();
  }

  /// Opens the OS share sheet with a plain-text itinerary. [sharePositionOrigin]
  /// anchors the sheet on iPad (required there, ignored on iPhone).
  static Future<void> share(Trip trip, {Rect? sharePositionOrigin}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: buildText(trip),
        subject: trip.name,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Builds a PDF that mirrors the app's timeline UI and opens the OS share
  /// sheet with it as a file.
  static Future<void> sharePdf(Trip trip, {Rect? sharePositionOrigin}) async {
    final bytes = await ItineraryPdf.buildBytes(trip);
    final name = trip.name.trim().isEmpty
        ? 'itinerary'
        : trip.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').replaceAll(' ', '_');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: trip.name,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
