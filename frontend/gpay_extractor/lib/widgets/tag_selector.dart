import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Chip-based tag selector for transaction categorization.
class TagSelector extends StatelessWidget {
  final String selectedTag;
  final ValueChanged<String> onTagSelected;

  const TagSelector({
    super.key,
    required this.selectedTag,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            color: const Color(0xFF1A1D26).withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConfig.tags.map((tag) {
            final isSelected = tag == selectedTag;
            final colorValue = AppConfig.tagColors[tag] ?? 0xFF8D99AE;
            final color = Color(colorValue);
            final icon = AppConfig.tagIcons[tag] ?? Icons.more_horiz;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTagSelected(tag),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.12)
                          : const Color(0xFFF0F2F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.4)
                            : const Color(0xFFE0E4EF),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected
                              ? color
                              : const Color(0xFF1A1D26).withOpacity(0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tag,
                          style: TextStyle(
                            color: isSelected
                                ? color
                                : const Color(0xFF1A1D26).withOpacity(0.55),
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
