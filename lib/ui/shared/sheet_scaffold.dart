import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared chrome for the app's bottom sheets: grab handle, title, an optional
/// destructive action, a body, and a gradient save button. Resizes with the
/// keyboard.
class SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// When null the save button is shown but disabled (use for "no changes yet").
  final VoidCallback? onSave;
  final String saveLabel;

  /// Optional header actions. [onEdit] (pencil) enters edit mode; [onDone]
  /// (checkmark) confirms edits and returns to view mode — pass one or the
  /// other. [onDelete] (trash) is shown in both.
  final VoidCallback? onEdit;
  final VoidCallback? onDone;

  /// When true the done action reads as "save" (filled check); when false it
  /// reads as "no changes — just close" (outline check).
  final bool doneActive;
  final VoidCallback? onDelete;

  /// Whether to show the save button at all (false = view-only sheets).
  final bool showSave;

  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onSave,
    this.saveLabel = 'Save',
    this.onEdit,
    this.onDone,
    this.doneActive = true,
    this.onDelete,
    this.showSave = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          // Shrink by the keyboard height too, so a focused field's own
          // auto-scroll (Scrollable.ensureVisible) brings it just above the
          // keyboard instead of the whole sheet jumping/overflowing upward.
          maxHeight: (screenHeight * 0.9 - bottomInset).clamp(
            0.0,
            screenHeight * 0.9,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(24),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, color: AppColors.accent),
                    ),
                  if (onDone != null)
                    IconButton(
                      onPressed: onDone,
                      tooltip: doneActive ? 'Save changes' : 'Close',
                      // No changes → an X (just close edit); a change made →
                      // a filled check (save).
                      icon: Icon(
                        doneActive
                            ? Icons.check_circle_rounded
                            : Icons.close_rounded,
                        color: doneActive
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            if (showSave)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  4,
                  24,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: _SaveButton(label: saveLabel, onTap: onSave),
              )
            else
              SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SaveButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: AppText.body(
              16,
              color: Colors.black,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
