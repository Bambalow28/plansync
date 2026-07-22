import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/address_search_service.dart';
import '../../services/connectivity_service.dart';
import '../../theme/app_theme.dart';

/// A hotel/lodging address field with Mapbox geocoding autocomplete when
/// online. Unlike [PlaceSearchField]'s offline city dataset, suggestions here
/// need the network — but whatever's typed is always accepted and saved as
/// plain text, so entering (or keeping) an address works offline too.
///
/// The suggestion dropdown floats over the page (an [OverlayPortal] anchored
/// to the field) instead of pushing the rest of the layout down.
class HotelAddressField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;

  const HotelAddressField({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<HotelAddressField> createState() => _HotelAddressFieldState();
}

/// Show at most this many suggestions in the dropdown.
const _kMaxSuggestions = 3;

class _HotelAddressFieldState extends State<HotelAddressField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');
  final _focusNode = FocusNode();
  final _link = LayerLink();
  final _overlayController = OverlayPortalController();
  Timer? _debounce;
  StreamSubscription<bool>? _connSub;

  List<String> _suggestions = const [];
  bool _loading = false;
  bool _online = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _connSub = ConnectivityService.instance.onlineStream.listen(_setOnline);
    ConnectivityService.instance.isOnline().then(_setOnline);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _setOnline(bool online) {
    if (!mounted) return;
    setState(() => _online = online);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connSub?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged(value);
    _debounce?.cancel();
    if (!_online) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(value));
    setState(() {});
  }

  Future<void> _runSearch(String value) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final results = await AddressSearchService.instance.search(value);
    if (!mounted || seq != _seq) return;
    setState(() {
      _suggestions = results.take(_kMaxSuggestions).toList();
      _loading = false;
    });
  }

  void _select(String address) {
    _debounce?.cancel();
    setState(() {
      _controller.text = address;
      _suggestions = const [];
    });
    _focusNode.unfocus();
    widget.onChanged(address);
  }

  OutlineInputBorder _border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));

  @override
  Widget build(BuildContext context) {
    final showOverlay = _focusNode.hasFocus && _suggestions.isNotEmpty;
    // Deferred a frame: toggling the controller synchronously during build
    // can fire before the OverlayPortal below has actually mounted, which
    // trips an internal Flutter assertion (_zOrderIndex != null).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (showOverlay) {
        _overlayController.show();
      } else {
        _overlayController.hide();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _link,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return OverlayPortal(
                controller: _overlayController,
                overlayChildBuilder: (context) => CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  followerAnchor: Alignment.topLeft,
                  offset: const Offset(0, 6),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: _Dropdown(suggestions: _suggestions, onSelect: _select),
                    ),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  style: AppText.body(15),
                  cursorColor: AppColors.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Hotel address (optional)',
                    hintStyle: AppText.body(15, color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.hotel_rounded, size: 18, color: AppColors.textMuted),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceLow,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: _border(Colors.white.withValues(alpha: 0.06)),
                    enabledBorder: _border(Colors.white.withValues(alpha: 0.06)),
                    focusedBorder: _border(AppColors.accent),
                  ),
                ),
              );
            },
          ),
        ),
        if (_focusNode.hasFocus && !_online)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              "You're offline — suggestions need internet, but you can still type the address.",
              style: AppText.label(11, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// The floating suggestion panel itself.
class _Dropdown extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelect;
  const _Dropdown({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < suggestions.length; i++)
              _SuggestionTile(
                address: suggestions[i],
                showDivider: i != suggestions.length - 1,
                onTap: () => onSelect(suggestions[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String address;
  final bool showDivider;
  final VoidCallback onTap;
  const _SuggestionTile({
    required this.address,
    required this.showDivider,
    required this.onTap,
  });

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
            Icon(Icons.location_on_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                address,
                style: AppText.body(14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
