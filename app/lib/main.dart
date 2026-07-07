import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/notes/note_models.dart';
import 'src/providers.dart';

void main() {
  runApp(const ProviderScope(child: RecallApp()));
}

class RecallApp extends StatelessWidget {
  const RecallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recall',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const RecallHomePage(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const seed = Color(0xFF3A6A60);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class RecallHomePage extends ConsumerWidget {
  const RecallHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notePreviewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recall'),
        actions: [
          IconButton(
            tooltip: 'Sync',
            onPressed: () {},
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverToBoxAdapter(child: HomeControls()),
            ),
            notes.when(
              data: _notesSliver,
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(message: error.toString()),
              ),
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNoteDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Note'),
      ),
    );
  }

  Widget _notesSliver(List<NotePreview> notes) {
    if (notes.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 184,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) => NoteCard(note: notes[index]),
      ),
    );
  }
}

class HomeControls extends StatelessWidget {
  const HomeControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NoteSearchField(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Pinned'),
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Due soon'),
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Archive'),
              onSelected: (_) {},
            ),
          ],
        ),
      ],
    );
  }
}

class NoteSearchField extends StatelessWidget {
  const NoteSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search notes',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Voice note',
          onPressed: () {},
          icon: const Icon(Icons.mic_none_rounded),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_outlined, size: 48, color: colors.primary),
            const SizedBox(height: 16),
            Text('No notes yet', style: textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Create one to start building your Recall library.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.error),
        ),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note});

  final NotePreview note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = note.mood.resolve(Theme.of(context).brightness);

    return Card(
      color: colors.background,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (note.pinned)
                    Icon(
                      Icons.push_pin_outlined,
                      size: 18,
                      color: colors.accent,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: note.checklistItems.isEmpty
                    ? Text(
                        note.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.foreground),
                      )
                    : ChecklistPreview(
                        items: note.checklistItems,
                        foreground: colors.foreground,
                        accent: colors.accent,
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    note.recurring ? Icons.event_repeat_rounded : Icons.notifications_none_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note.reminderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.foreground.withValues(alpha: 0.78),
                          ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.28)),
            ],
          ),
        ),
      ),
    );
  }
}

class ChecklistPreview extends StatelessWidget {
  const ChecklistPreview({
    super.key,
    required this.items,
    required this.foreground,
    required this.accent,
  });

  final List<ChecklistItemPreview> items;
  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  item.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: item.done ? accent : foreground.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _showCreateNoteDialog(BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();

  final shouldCreate = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            decoration: const InputDecoration(labelText: 'Note'),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Create'),
        ),
      ],
    ),
  );

  final title = titleController.text;
  final body = bodyController.text;
  titleController.dispose();
  bodyController.dispose();

  if (shouldCreate != true || (title.trim().isEmpty && body.trim().isEmpty)) {
    return;
  }

  await ref.read(notesRepositoryProvider).createTextNote(
        title: title,
        body: body,
      );
}
