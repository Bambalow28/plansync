import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/place.dart';
import '../../services/place_search_service.dart';
import '../../theme/app_theme.dart';

/// A location field that shows a debounced dropdown of real cities from the
/// offline dataset. A place is only "chosen" once the user taps a suggestion;
/// editing the text clears the selection so callers can require a valid place.
class PlaceSearchField extends StatefulWidget {
  final Place? initialValue;
  final ValueChanged<Place?> onSelected;
  final String hint;
  // Manual flight entry covers airports/cities the offline dataset won't have
  // a suggestion for — commit whatever was typed on blur instead of requiring
  // a dropdown match.
  final bool allowFreeText;

  const PlaceSearchField({
    super.key,
    required this.onSelected,
    this.initialValue,
    this.hint = 'Search city — e.g. Tokyo',
    this.allowFreeText = false,
  });

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue?.label ?? '');
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Place> _suggestions = const [];
  bool _loading = false;
  Place? _selected;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(PlaceSearchField old) {
    super.didUpdateWidget(old);
    // Reflect a value set programmatically by the parent (e.g. flight auto-fill)
    // — but only when it's a real, different place, so this never clobbers the
    // text while the user is typing (which drives initialValue back to null).
    final v = widget.initialValue;
    if (v != null && v != old.initialValue && v != _selected) {
      _selected = v;
      _controller.text = v.label;
      _suggestions = const [];
    }
  }

  void _onFocusChange() {
    if (!mounted) return;
    // Losing focus with unmatched typed text: for free-text fields, commit it
    // as a place instead of silently dropping back to null.
    if (!_focusNode.hasFocus && widget.allowFreeText && _selected == null) {
      final text = _controller.text.trim();
      if (text.isNotEmpty) {
        final place = Place(city: text);
        setState(() {
          _selected = place;
          _suggestions = const [];
        });
        widget.onSelected(place);
        return;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_selected != null) {
      _selected = null;
      widget.onSelected(null);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(value));
    setState(() {});
  }

  Future<void> _runSearch(String value) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final results = await PlaceSearchService.instance.search(value);
    if (!mounted || seq != _seq) return;
    setState(() {
      _suggestions = results;
      _loading = false;
    });
  }

  void _select(Place place) {
    _debounce?.cancel();
    setState(() {
      _selected = place;
      _controller.text = place.label;
      _suggestions = const [];
    });
    _focusNode.unfocus();
    widget.onSelected(place);
  }

  OutlineInputBorder _border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().length >= 2;
    final showList = _focusNode.hasFocus && _selected == null && (_suggestions.isNotEmpty || (_loading && hasQuery));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          onTap: () => setState(() {}),
          textCapitalization: TextCapitalization.words,
          style: AppText.body(15),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle: AppText.body(15, color: AppColors.textMuted),
            prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: AppColors.textMuted),
            suffixIcon: _selected != null
                ? Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accent)
                : (_loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        ),
                      )
                    : null),
            filled: true,
            fillColor: AppColors.surfaceLow,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: _border(Colors.white.withValues(alpha: 0.06)),
            focusedBorder: _border(AppColors.accent),
          ),
        ),
        if (showList)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: _loading && _suggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('Searching…', style: AppText.label(12, color: AppColors.textSecondary))),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < _suggestions.length; i++)
                        _SuggestionTile(
                          place: _suggestions[i],
                          showDivider: i != _suggestions.length - 1,
                          onTap: () => _select(_suggestions[i]),
                        ),
                    ],
                  ),
          ),
        if (_focusNode.hasFocus && _selected == null && !_loading && _suggestions.isEmpty && hasQuery)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text('No matching city found', style: AppText.label(11, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final Place place;
  final bool showDivider;
  final VoidCallback onTap;
  const _SuggestionTile({required this.place, required this.showDivider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.location_city_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.city, style: AppText.body(14)),
                  if (place.country.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(place.country, style: AppText.label(10, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
