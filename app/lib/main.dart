import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/notes/note_models.dart';
import 'src/providers.dart';
import 'src/updates/apk_installer.dart';
import 'src/updates/update_service.dart';

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
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

class RecallHomePage extends ConsumerStatefulWidget {
  const RecallHomePage({super.key});

  @override
  ConsumerState<RecallHomePage> createState() => _RecallHomePageState();
}

class _RecallHomePageState extends ConsumerState<RecallHomePage> {
  bool _startupUpdateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkForUpdatesOnStartup(),
    );
  }

  Future<void> _checkForUpdatesOnStartup() async {
    if (_startupUpdateCheckStarted || !mounted) {
      return;
    }

    _startupUpdateCheckStarted = true;

    try {
      final update = await ref.read(updateServiceProvider).checkForUpdate();
      if (mounted && update.updateAvailable) {
        await _showUpdateAvailableDialog(context, ref, update);
      }
    } on UpdateException {
      // Startup checks stay quiet. Manual checks surface errors in settings.
    } on Object {
      // Network failures should not interrupt opening the app.
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _showSettingsSheet(context, ref),
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
            FilterChip(label: const Text('Pinned'), onSelected: (_) {}),
            FilterChip(label: const Text('Due soon'), onSelected: (_) {}),
            FilterChip(label: const Text('Archive'), onSelected: (_) {}),
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
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
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

enum _NoteCardAction { delete }

class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.note});

  final NotePreview note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  SizedBox.square(
                    dimension: 32,
                    child: PopupMenuButton<_NoteCardAction>(
                      tooltip: 'Note actions',
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: colors.foreground,
                      ),
                      onSelected: (action) async {
                        switch (action) {
                          case _NoteCardAction.delete:
                            await _confirmMoveNoteToTrash(context, ref, note);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _NoteCardAction.delete,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Delete'),
                          ),
                        ),
                      ],
                    ),
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
                    note.recurring
                        ? Icons.event_repeat_rounded
                        : Icons.notifications_none_rounded,
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
    final visibleItems = items.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in visibleItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  item.done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
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
        if (items.length > visibleItems.length)
          Text(
            '+${items.length - visibleItems.length} more',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}

Future<void> _confirmMoveNoteToTrash(
  BuildContext context,
  WidgetRef ref,
  NotePreview note,
) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete note?'),
      content: Text('"${note.title}" will be moved to trash.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
      ],
    ),
  );

  if (shouldDelete != true || !context.mounted) {
    return;
  }

  await ref.read(notesRepositoryProvider).moveNoteToTrash(note.id);

  if (context.mounted) {
    _showSnackBar(context, 'Note moved to trash.');
  }
}

Future<void> _showSettingsSheet(BuildContext context, WidgetRef ref) {
  var checkingForUpdates = false;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Version'),
                subtitle: Text(appVersion),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: checkingForUpdates
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt_rounded),
                title: const Text('Check for updates'),
                enabled: !checkingForUpdates,
                onTap: checkingForUpdates
                    ? null
                    : () async {
                        setSheetState(() => checkingForUpdates = true);
                        await _checkForUpdatesManually(
                          context,
                          sheetContext,
                          ref,
                        );
                        if (sheetContext.mounted) {
                          setSheetState(() => checkingForUpdates = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _checkForUpdatesManually(
  BuildContext rootContext,
  BuildContext sheetContext,
  WidgetRef ref,
) async {
  try {
    final update = await ref.read(updateServiceProvider).checkForUpdate();
    if (!rootContext.mounted || !sheetContext.mounted) {
      return;
    }

    if (!update.updateAvailable) {
      _showSnackBar(rootContext, 'Recall is up to date.');
      return;
    }

    Navigator.of(sheetContext).pop();
    await _showUpdateAvailableDialog(rootContext, ref, update);
  } on UpdateException catch (error) {
    if (rootContext.mounted) {
      _showSnackBar(rootContext, error.message);
    }
  } on Object {
    if (rootContext.mounted) {
      _showSnackBar(rootContext, 'Could not check for updates.');
    }
  }
}

Future<void> _showUpdateAvailableDialog(
  BuildContext context,
  WidgetRef ref,
  UpdateCheckResult update,
) async {
  final shouldInstall = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Update available'),
      content: Text(
        'Recall ${update.latestVersion} is available. '
        'You have ${update.currentVersion}.${update.downloadSizeBytes == null ? '' : '\n\nDownload size: ${_formatBytes(update.downloadSizeBytes!)}'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Install'),
        ),
      ],
    ),
  );

  if (shouldInstall == true && context.mounted) {
    await _downloadAndInstallUpdate(context, ref, update);
  }
}

Future<void> _downloadAndInstallUpdate(
  BuildContext context,
  WidgetRef ref,
  UpdateCheckResult update,
) async {
  final progress = ValueNotifier<double?>(null);
  var dialogOpen = true;

  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Downloading update'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: value),
            const SizedBox(height: 16),
            Text(
              value == null
                  ? 'Preparing download...'
                  : '${(value * 100).round()}%',
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  try {
    final file = await ref
        .read(updateServiceProvider)
        .downloadApk(
          update,
          onProgress: (received, total) {
            if (total == null || total == 0) {
              progress.value = null;
            } else {
              progress.value = received / total;
            }
          },
        );

    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;

    await ref.read(apkInstallerProvider).installApk(file.path);
  } on InstallPermissionRequiredException {
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
    if (context.mounted) {
      await _showInstallPermissionDialog(context, ref);
    }
  } on UpdateException catch (error) {
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
    if (context.mounted) {
      _showSnackBar(context, error.message);
    }
  } on ApkInstallException catch (error) {
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
    if (context.mounted) {
      _showSnackBar(context, error.message);
    }
  } on Object {
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
    if (context.mounted) {
      _showSnackBar(context, 'Could not install the update.');
    }
  } finally {
    progress.dispose();
  }
}

Future<void> _showInstallPermissionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Permission needed'),
      content: const Text(
        'Android needs permission for Recall to install downloaded updates.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );

  if (openSettings == true) {
    await ref.read(apkInstallerProvider).openInstallPermissionSettings();
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  return '$bytes B';
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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

  await ref
      .read(notesRepositoryProvider)
      .createTextNote(title: title, body: body);
}
