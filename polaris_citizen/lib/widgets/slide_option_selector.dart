import 'package:flutter/material.dart';

class SlideOptionSelector<T> extends StatelessWidget {
  const SlideOptionSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.keyBuilder,
    this.optionColorBuilder,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelBuilder;
  final void Function(T option) onSelected;
  final Key? Function(T option)? keyBuilder;
  final Color? Function(T option)? optionColorBuilder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int selectedIndex = options
        .indexOf(selected)
        .clamp(0, options.length - 1);
    final Color selectedTone =
        optionColorBuilder?.call(options[selectedIndex]) ?? colors.primary;

    if (options.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double segmentWidth = (width - 8) / options.length;
        const double thumbInset = 1.5;
        final double thumbWidth = (segmentWidth - (thumbInset * 2)).clamp(
          0,
          segmentWidth,
        );

        return GestureDetector(
          onHorizontalDragEnd: (DragEndDetails details) {
            final double velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 120) return;
            final int next = velocity > 0
                ? selectedIndex + 1
                : selectedIndex - 1;
            if (next >= 0 && next < options.length) onSelected(options[next]);
          },
          child: Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant, width: 0.9),
            ),
            child: Stack(
              children: <Widget>[
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  left: (selectedIndex * segmentWidth) + thumbInset,
                  top: 0,
                  bottom: 0,
                  width: thumbWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectedTone.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selectedTone, width: 1),
                    ),
                  ),
                ),
                Row(
                  children: options.map((T option) {
                    final bool isSelected = option == selected;
                    final Color optionTone =
                        optionColorBuilder?.call(option) ?? colors.primary;
                    return Expanded(
                      child: InkWell(
                        key: keyBuilder?.call(option),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onSelected(option),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              labelBuilder(option),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.2,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? optionTone
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
