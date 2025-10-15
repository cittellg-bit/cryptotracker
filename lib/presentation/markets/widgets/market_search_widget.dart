import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class MarketSearchWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final int resultCount;
  final String query;
  final VoidCallback onClear;

  const MarketSearchWidget({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.resultCount,
    required this.query,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search cryptocurrencies...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'search',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: onClear,
                        icon: CustomIconWidget(
                          iconName: 'close',
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          size: 20,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 1.5.h,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Text(
                query.isEmpty
                    ? '$resultCount cryptocurrencies'
                    : '$resultCount results for "$query"',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              if (isSearching)
                Row(
                  children: [
                    SizedBox(
                      width: 4.w,
                      height: 4.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Searching...',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
