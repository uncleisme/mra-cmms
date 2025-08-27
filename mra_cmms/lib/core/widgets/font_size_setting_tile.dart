// Removed unused helper import
// Removed: import 'package:group_button/group_button_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart' show AppFontSize, fontSizeProvider;
import 'package:group_button/group_button.dart';

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
            final controller = GroupButtonController(
              selectedIndex: AppFontSize.values.indexOf(tempValue),
            );
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
                      GroupButton<AppFontSize>(
                        isRadio: true,
                        buttons: AppFontSize.values,
                        controller: controller,
                        onSelected: (value, index, isSelected) {
                          setState(() => tempValue = value);
                        },
                        buttonTextBuilder: (value, context, selected) =>
                            fontSizeLabel(value as AppFontSize),
                        options: const GroupButtonOptions(
                          selectedColor: Colors.blue,
                          unselectedColor: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
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
