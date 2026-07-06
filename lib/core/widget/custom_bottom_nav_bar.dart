import 'package:flutter/material.dart';
import '../constants/dimensions.dart';
import '../utils/ui_spacer.dart';
import 'custom_app_text.dart';
import 'custom_image_widget.dart';

class NavItem {
  final String icon;
  final String label;

  NavItem({required this.icon, required this.label});
}

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<NavItem> items;
  final Function(int) onItemSelected;

  const CustomBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            items.length,
                (index) => _buildNavItem(
              context,
              items[index].icon,
              items[index].label,
              index,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context,
      String icon,
      String label,
      int index,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isSelected = selectedIndex == index;

    // Selected state colors
    final selectedBgColor = theme.colorScheme.primary;
    final selectedIconColor = isDark ? Colors.white : Colors.black;
    final selectedTextColor = isDark ? Colors.white : Colors.black;

    // Unselected state colors
    final unselectedIconColor = isDark
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.5);
    final unselectedTextColor = isDark
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.5);

    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomImageWidget(
              height: 20,
              width: 20,
              imagePath: icon,
              color: isSelected ? selectedIconColor : unselectedIconColor,
            ),
            UiSpacer.verticalSpace(space: 5),
            CustomAppText(
              label,
              style: TextStyle(
                color: isSelected ? selectedTextColor : unselectedTextColor,
                fontSize: Dimensions.font12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
