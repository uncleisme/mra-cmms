import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart' show AppFontSize, fontSizeProvider;

String fontSizeLabel(AppFontSize option) {
  switch (option) {
    case AppFontSize.small:
      return 'Small';
    case AppFontSize.medium:
      return 'Medium';
    case AppFontSize.large:
      return 'Large';
  }
}

class FontSizeSettingTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);
    return ListTile(
      leading: const Icon(Icons.text_fields),
      title: const Text('Font Size'),
      subtitle: Text(fontSizeLabel(fontSize)),
      onTap: () async {
        final picked = await showModalBottomSheet<AppFontSize>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            AppFontSize tempValue = fontSize;
            return StatefulBuilder(
              builder: (context, setState) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text(
                          'Font Size',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      RadioListTile<AppFontSize>(
                        value: AppFontSize.small,
                        groupValue: tempValue,
                        title: const Text('Small'),
                        onChanged: (v) => setState(() => tempValue = v!),
                      ),
                      RadioListTile<AppFontSize>(
                        value: AppFontSize.medium,
                        groupValue: tempValue,
                        title: const Text('Medium'),
                        onChanged: (v) => setState(() => tempValue = v!),
                      ),
                      RadioListTile<AppFontSize>(
                        value: AppFontSize.large,
                        groupValue: tempValue,
                        title: const Text('Large'),
                        onChanged: (v) => setState(() => tempValue = v!),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, tempValue),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
        if (picked != null) {
          ref.read(fontSizeProvider.notifier).state = picked;
        }
      },
    );
  }
}
