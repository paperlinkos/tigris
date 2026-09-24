import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/controllers/rich_text_editing_controller.dart';
import 'package:tigris/models/task_item.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/task_repository.dart';

void main() {
  group('RichTextEditingController Tests', () {
    testWidgets('Parses **bold**, _italic_, and ==highlight== into styled TextSpans', (WidgetTester tester) async {
      final controller = RichTextEditingController(text: '**bold** _italic_ ==highlight==');

      // Build text span in dummy context
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(span.children, isNotNull);
                expect(span.children!.length, greaterThanOrEqualTo(3));

                final boldSpan = span.children![0];
                expect(boldSpan.style?.fontWeight, equals(FontWeight.bold));

                final italicSpan = span.children![2];
                expect(italicSpan.style?.fontStyle, equals(FontStyle.italic));

                final highlightSpan = span.children![4];
                expect(highlightSpan.style?.backgroundColor, isNotNull);

                return Text.rich(span);
              },
            ),
          ),
        ),
      );
    });

    test('WYSIWYG: toggleBold formats selected text without inserting ** characters', () {
      final controller = RichTextEditingController(text: 'Hello world');
      // Select 'world' (offset 6 to 11)
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);

      // Apply bold
      controller.toggleBold();

      // Text itself MUST remain clean without any '**' characters
      expect(controller.text, equals('Hello world'));
      expect(controller.text.contains('**'), isFalse);
      expect(controller.spans.length, equals(1));
      expect(controller.spans.first.start, equals(6));
      expect(controller.spans.first.end, equals(11));
      expect(controller.spans.first.type, equals(AttributeType.bold));

      // Re-selecting and toggling removes the bold formatting
      controller.toggleBold();
      expect(controller.spans.isEmpty, isTrue);
      expect(controller.text, equals('Hello world'));
    });

    test('WYSIWYG: Serialization and deserialization preserves formatting', () {
      final controller = RichTextEditingController(text: 'Important note');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
      controller.toggleBold();

      final json = controller.exportFormatting();
      expect(json, isNotNull);
      expect(json, contains('"type":"bold"'));

      // Reload into another controller
      final reloaded = RichTextEditingController.fromNoteContent(
        content: 'Important note',
        formatting: json,
      );
      expect(reloaded.text, equals('Important note'));
      expect(reloaded.spans.length, equals(1));
      expect(reloaded.spans.first.start, equals(0));
      expect(reloaded.spans.first.end, equals(9));
      expect(reloaded.spans.first.type, equals(AttributeType.bold));
    });

    test('WYSIWYG: Typing text shifts span offsets automatically', () {
      final controller = RichTextEditingController(text: 'World');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      controller.toggleBold();

      // Prepend 'Hello ' before 'World'
      controller.value = const TextEditingValue(
        text: 'Hello World',
        selection: TextSelection.collapsed(offset: 6),
      );

      // Span for 'World' should be shifted to [6, 11]
      expect(controller.spans.length, equals(1));
      expect(controller.spans.first.start, equals(6));
      expect(controller.spans.first.end, equals(11));
      expect(controller.spans.first.type, equals(AttributeType.bold));
    });
  });

  group('TaskRepository Checklist Tests', () {
    late InMemoryStorage storage;
    late LocalTaskRepository repo;

    setUp(() {
      storage = InMemoryStorage();
      repo = LocalTaskRepository(storage: storage);
    });

    test('Creates, toggles, and deletes checklist tasks', () async {
      final task1 = TaskItem(
        id: 't1',
        title: 'Buy groceries',
        createdAt: DateTime.now(),
      );

      final task2 = TaskItem(
        id: 't2',
        title: 'Review notes',
        createdAt: DateTime.now(),
      );

      await repo.saveTask(task1);
      await repo.saveTask(task2);

      var all = await repo.getAllTasks();
      expect(all.length, equals(2));
      expect(all.any((t) => t.id == 't1' && !t.isCompleted), isTrue);

      // Toggle task1 to completed
      await repo.toggleTask('t1');
      all = await repo.getAllTasks();

      final updatedTask1 = all.firstWhere((t) => t.id == 't1');
      expect(updatedTask1.isCompleted, isTrue);
      expect(updatedTask1.completedAt, isNotNull);

      // Delete task2
      await repo.deleteTask('t2');
      all = await repo.getAllTasks();
      expect(all.length, equals(1));
      expect(all.first.id, equals('t1'));
    });
  });
}
