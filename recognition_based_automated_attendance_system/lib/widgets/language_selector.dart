import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/language_provider.dart';

class LanguageSelector extends StatelessWidget {
  final bool compact;

  const LanguageSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, language, _) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.glassBorder, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.translate_rounded,
                size: compact ? 16 : 18,
                color: AppTheme.primaryLight,
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: language.languageCode,
                  dropdownColor: AppTheme.bgCard,
                  iconEnabledColor: AppTheme.textSecondary,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: language.languageOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.code,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<LanguageProvider>().setLanguageCode(value);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
