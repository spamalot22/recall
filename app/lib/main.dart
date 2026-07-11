import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/account/auth_service.dart';
import 'src/account/secure_account_store.dart';
import 'src/notes/note_models.dart';
import 'src/notes/notes_repository.dart';
import 'src/providers.dart';
import 'src/reminders/reminder_scheduler.dart';
import 'src/sync/sync_service.dart';
import 'src/sync/background_sync.dart';
import 'src/updates/apk_installer.dart';
import 'src/updates/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RecallApp()));
}

class RecallApp extends ConsumerWidget {
  const RecallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = lightDynamic ?? _fallbackScheme(Brightness.light);
        final darkScheme = darkDynamic ?? _fallbackScheme(Brightness.dark);
        return MaterialApp(
          title: 'Recall',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: ref.watch(themeModeProvider),
          home: const RecallHomePage(),
        );
      },
    );
  }
}

ColorScheme _fallbackScheme(Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: const Color(0xFF356D64),
    brightness: brightness,
  );
}

ThemeData _buildTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 25,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
  );
}

enum _NoteFilter { all, pinned, dueSoon, archive }

extension on _NoteFilter {
  String get label => switch (this) {
    _NoteFilter.all => 'All',
    _NoteFilter.pinned => 'Pinned',
    _NoteFilter.dueSoon => 'Due soon',
    _NoteFilter.archive => 'Archive',
  };
}

class RecallHomePage extends ConsumerStatefulWidget {
  const RecallHomePage({super.key});

  @override
  ConsumerState<RecallHomePage> createState() => _RecallHomePageState();
}

class _RecallHomePageState extends ConsumerState<RecallHomePage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _notificationOpenSubscription;
  bool _startupUpdateCheckStarted = false;
  bool _gridLayout = true;
  _NoteFilter _filter = _NoteFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    final reminderScheduler = ref.read(reminderSchedulerProvider);
    _notificationOpenSubscription = reminderScheduler.openNoteRequests.listen(
      _openNoteFromNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(backgroundStartupEnabledProvider)) {
        return;
      }
      unawaited(_initializeRemindersQuietly(reminderScheduler));
      unawaited(_configureBackgroundSyncQuietly(ref));
      unawaited(_checkForUpdatesOnStartup());
      unawaited(_syncQuietly(ref));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notificationOpenSubscription?.cancel());
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(backgroundStartupEnabledProvider)) {
      // Background notification actions use their own database connection.
      ref.invalidate(notePreviewsProvider);
      unawaited(_syncQuietly(ref));
    }
  }

  void _onSearchChanged() => setState(() {});

  void _openNoteFromNotification(String noteId) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_openNoteEditor(context, noteId: noteId));
      }
    });
  }

  Future<void> _initializeRemindersQuietly(ReminderScheduler scheduler) async {
    try {
      await scheduler.initialize();
    } on Object {
      // Scheduling from the editor will surface any actionable failure.
    }
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
    } on Object {
      // Opening a local notes app must never depend on a release check.
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notePreviewsProvider);
    final session = ref.watch(storedSessionProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recall'),
        actions: [
          if (session != null)
            IconButton(
              tooltip: 'Sync encrypted backup',
              onPressed: () => _runSync(context, ref),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              sliver: SliverToBoxAdapter(
                child: _HomeControls(
                  controller: _searchController,
                  filter: _filter,
                  gridLayout: _gridLayout,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                  onLayoutChanged: (gridLayout) =>
                      setState(() => _gridLayout = gridLayout),
                ),
              ),
            ),
            notes.when(
              data: (items) => _notesSliver(_visibleNotes(items)),
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
        onPressed: () => _openNoteEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Note'),
      ),
    );
  }

  List<NotePreview> _visibleNotes(List<NotePreview> notes) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final dueSoon = now.add(const Duration(days: 7));

    return notes.where((note) {
      final matchesFilter = switch (_filter) {
        _NoteFilter.all => !note.archived,
        _NoteFilter.pinned => !note.archived && note.pinned,
        _NoteFilter.dueSoon =>
          !note.archived &&
              note.reminderAt != null &&
              note.reminderAt!.isAfter(now) &&
              !note.reminderAt!.isAfter(dueSoon),
        _NoteFilter.archive => note.archived,
      };
      if (!matchesFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return note.title.toLowerCase().contains(query) ||
          note.body.toLowerCase().contains(query) ||
          note.checklistItems.any(
            (item) => item.text.toLowerCase().contains(query),
          );
    }).toList();
  }

  Widget _notesSliver(List<NotePreview> notes) {
    if (notes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          searching: _searchController.text.trim().isNotEmpty,
          filter: _filter,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      sliver: _gridLayout
          ? SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 1100
                    ? 4
                    : width >= 700
                    ? 3
                    : 2;
                return SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 204,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) => NoteCard(note: notes[index]),
                );
              },
            )
          : SliverList.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 176,
                  child: NoteCard(note: notes[index]),
                ),
              ),
            ),
    );
  }
}

class _HomeControls extends StatelessWidget {
  const _HomeControls({
    required this.controller,
    required this.filter,
    required this.gridLayout,
    required this.onFilterChanged,
    required this.onLayoutChanged,
  });

  final TextEditingController controller;
  final _NoteFilter filter;
  final bool gridLayout;
  final ValueChanged<_NoteFilter> onFilterChanged;
  final ValueChanged<bool> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search notes',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: controller.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final value in _NoteFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(value.label),
                          selected: filter == value,
                          onSelected: (_) => onFilterChanged(value),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: gridLayout ? 'Use list layout' : 'Use grid layout',
              onPressed: () => onLayoutChanged(!gridLayout),
              icon: Icon(
                gridLayout
                    ? Icons.view_agenda_outlined
                    : Icons.grid_view_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching, required this.filter});

  final bool searching;
  final _NoteFilter filter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isFresh = !searching && filter == _NoteFilter.all;
    final text = searching
        ? 'No matching notes'
        : isFresh
        ? 'No notes yet'
        : 'Nothing here yet';
    final detail = searching
        ? 'Try another word or clear the search.'
        : isFresh
        ? 'Capture a thought, a task, or something you want to remember.'
        : 'Notes matching this view will appear here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.note_add_outlined,
              size: 48,
              color: colors.primary,
            ),
            const SizedBox(height: 16),
            Text(text, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

enum _NoteCardAction { pin, archive, delete }

class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.note});

  final NotePreview note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = note.mood.resolve(Theme.of(context).colorScheme);
    final hasReminder = note.reminderAt != null;
    final hasTitle = note.title.trim().isNotEmpty;

    return Card(
      color: colors.background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openNoteEditor(context, noteId: note.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (hasTitle)
                    Expanded(
                      child: Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.foreground,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (note.pinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: colors.accent,
                      ),
                    ),
                  PopupMenuButton<_NoteCardAction>(
                    tooltip: 'Note actions',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.foreground,
                    ),
                    onSelected: (action) => _runAction(context, ref, action),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _NoteCardAction.pin,
                        child: _MenuItem(
                          icon: note.pinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin_rounded,
                          label: note.pinned ? 'Unpin' : 'Pin',
                        ),
                      ),
                      PopupMenuItem(
                        value: _NoteCardAction.archive,
                        child: _MenuItem(
                          icon: note.archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          label: note.archived ? 'Unarchive' : 'Archive',
                        ),
                      ),
                      const PopupMenuItem(
                        value: _NoteCardAction.delete,
                        child: _MenuItem(
                          icon: Icons.delete_outline_rounded,
                          label: 'Move to trash',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: hasTitle ? 8 : 2),
              Expanded(
                child: note.checklistItems.isEmpty
                    ? Text(
                        note.body,
                        maxLines: hasTitle ? 5 : 7,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.foreground.withValues(alpha: 0.9),
                          fontSize: hasTitle ? null : 16,
                          height: 1.35,
                        ),
                      )
                    : ChecklistPreview(
                        noteId: note.id,
                        items: note.checklistItems,
                        foreground: colors.foreground,
                        accent: colors.accent,
                      ),
              ),
              if (hasReminder || note.checklistItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasReminder) ...[
                      Icon(
                        note.recurring
                            ? Icons.event_repeat_rounded
                            : Icons.notifications_none_rounded,
                        size: 16,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note.reminderLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.foreground.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (note.checklistItems.isNotEmpty)
                      Text(
                        '${note.completedChecklistItems}/${note.checklistItems.length}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.foreground.withValues(alpha: 0.72),
                            ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    _NoteCardAction action,
  ) async {
    final repository = ref.read(notesRepositoryProvider);
    switch (action) {
      case _NoteCardAction.pin:
        await repository.setPinned(note.id, !note.pinned);
        unawaited(_syncQuietly(ref));
        if (context.mounted) {
          _showSnackBar(
            context,
            note.pinned ? 'Note unpinned.' : 'Note pinned.',
          );
        }
      case _NoteCardAction.archive:
        final archived = !note.archived;
        await repository.setArchived(note.id, archived);
        unawaited(_syncQuietly(ref));
        if (context.mounted) {
          _showSnackBar(
            context,
            archived ? 'Note archived.' : 'Note restored.',
            actionLabel: 'Undo',
            onAction: () {
              unawaited(
                repository.setArchived(note.id, note.archived).then((_) {
                  return _syncQuietly(ref);
                }),
              );
            },
          );
        }
      case _NoteCardAction.delete:
        await _confirmMoveNoteToTrash(context, ref, note);
    }
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}

class ChecklistPreview extends ConsumerWidget {
  const ChecklistPreview({
    super.key,
    required this.noteId,
    required this.items,
    required this.foreground,
    required this.accent,
  });

  final String noteId;
  final List<ChecklistItemPreview> items;
  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleItems = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visibleItems.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                await ref
                    .read(notesRepositoryProvider)
                    .toggleChecklistItem(noteId, index);
                unawaited(_syncQuietly(ref));
              },
              child: Row(
                children: [
                  Icon(
                    visibleItems[index].done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: visibleItems[index].done
                        ? accent
                        : foreground.withValues(alpha: 0.66),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      visibleItems[index].text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        decoration: visibleItems[index].done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (items.length > visibleItems.length)
          Text(
            '+${items.length - visibleItems.length} more',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground.withValues(alpha: 0.68),
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
      title: const Text('Move note to trash?'),
      content: Text('"${_noteLabel(note)}" can be restored from trash later.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Move to trash'),
        ),
      ],
    ),
  );

  if (shouldDelete != true || !context.mounted) {
    return;
  }
  await ref.read(notesRepositoryProvider).moveNoteToTrash(note.id);
  await ref.read(reminderSchedulerProvider).cancelNoteReminder(note.id);
  unawaited(_syncQuietly(ref));
  if (context.mounted) {
    _showSnackBar(
      context,
      'Note moved to trash.',
      actionLabel: 'Undo',
      onAction: () {
        unawaited(
          ref.read(notesRepositoryProvider).restoreNote(note.id).then((
            _,
          ) async {
            await _reconcileRemindersQuietly(ref);
            await _syncQuietly(ref);
          }),
        );
      },
    );
  }
}

Future<void> _showSettingsSheet(BuildContext context, WidgetRef ref) async {
  var checkingForUpdates = false;
  int? pendingSyncChanges;
  StoredSession? session;
  try {
    session = await ref.read(storedSessionProvider.future);
  } on Object {
    // Settings that do not require the account remain available.
  }
  var backgroundSyncSettings = BackgroundSyncSettings.defaults;
  if (session != null) {
    try {
      backgroundSyncSettings = await ref
          .read(backgroundSyncControllerProvider)
          .loadSettings();
      pendingSyncChanges = await ref
          .read(syncServiceProvider)
          .pendingChangeCount();
    } on Object {
      // Keep defaults available if Android secure storage is temporarily busy.
    }
  }
  if (!context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Appearance',
                  style: Theme.of(sheetContext).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {ref.watch(themeModeProvider)},
                  onSelectionChanged: (selected) {
                    ref.read(themeModeProvider.notifier).state =
                        selected.single;
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    session == null
                        ? Icons.cloud_outlined
                        : Icons.cloud_done_outlined,
                  ),
                  title: Text(
                    session == null
                        ? 'Connect encrypted backup'
                        : 'Encrypted backup',
                  ),
                  subtitle: Text(
                    session == null
                        ? 'Keep an end-to-end encrypted copy at home'
                        : session.account.email,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountPage()),
                    );
                  },
                ),
                if (session != null) ...[
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.sync_disabled_rounded),
                    title: Text('Background sync'),
                    subtitle: Text(
                      'Temporarily disabled; sync still runs when Recall opens',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sync status',
                    style: Theme.of(sheetContext).textTheme.labelLarge,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_done_outlined),
                    title: const Text('Last successful sync'),
                    subtitle: Text(
                      _syncTimeLabel(backgroundSyncSettings.lastSuccessfulAt),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: const Text('Last attempt'),
                    subtitle: Text(
                      _syncTimeLabel(backgroundSyncSettings.lastAttemptAt),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: const Text('Pending changes'),
                    subtitle: Text(
                      pendingSyncChanges == null
                          ? 'Unavailable'
                          : pendingSyncChanges == 0
                          ? 'Everything is backed up'
                          : '$pendingSyncChanges waiting to sync',
                    ),
                  ),
                  if (backgroundSyncSettings.lastFailure != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.error_outline_rounded,
                        color: Theme.of(sheetContext).colorScheme.error,
                      ),
                      title: const Text('Last sync problem'),
                      subtitle: Text(backgroundSyncSettings.lastFailure!),
                    ),
                  const SizedBox(height: 4),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Trash'),
                  subtitle: const Text('Restore or permanently remove notes'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TrashPage()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: checkingForUpdates
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded),
                  title: const Text('Check for updates'),
                  subtitle: Text('Version $appVersion'),
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
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _serverController = TextEditingController(
    text: const String.fromEnvironment('RECALL_API_URL'),
  );
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  bool _registering = false;
  bool _recovering = false;
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccount() async {
    final session = await ref.read(storedSessionProvider.future);
    if (!mounted || session == null) {
      return;
    }
    _serverController.text = session.account.serverUrl;
    _emailController.text = session.account.email;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(storedSessionProvider).asData?.value;
    if (session != null) {
      return _ConnectedBackupPage(session: session);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted backup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              _recovering
                  ? 'Recover your account'
                  : _registering
                  ? 'Create backup account'
                  : 'Connect your backup',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Recall encrypts notes on this device before they leave it.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _serverController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Backup URL',
                hintText: 'https://recall.example.com',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 12),
            if (_recovering) ...[
              TextField(
                controller: _recoveryKeyController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [],
                decoration: const InputDecoration(
                  labelText: 'Recovery key',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: [
                _registering || _recovering
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: _recovering ? 'New password' : 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _recovering
                          ? Icons.key_rounded
                          : _registering
                          ? Icons.person_add_alt_1_rounded
                          : Icons.login_rounded,
                    ),
              label: Text(
                _recovering
                    ? 'Recover account'
                    : _registering
                    ? 'Create account'
                    : 'Sign in',
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                      if (_recovering) {
                        _recovering = false;
                      } else {
                        _registering = !_registering;
                      }
                    }),
              child: Text(
                _recovering
                    ? 'Back to sign in'
                    : _registering
                    ? 'I already have an account'
                    : 'Create an account on this backup',
              ),
            ),
            if (!_registering && !_recovering)
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _recovering = true),
                child: const Text('Use a recovery key'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_serverController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        (_recovering && _recoveryKeyController.text.trim().isEmpty)) {
      _showSnackBar(context, 'Complete all account fields.');
      return;
    }
    if ((_registering || _recovering) && _passwordController.text.length < 12) {
      _showSnackBar(context, 'Use a password with at least 12 characters.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = ref.read(authServiceProvider);
      final result = _recovering
          ? await service.recover(
              serverUrl: _serverController.text,
              email: _emailController.text,
              recoveryKey: _recoveryKeyController.text,
              newPassword: _passwordController.text,
              deviceName: 'Android device',
            )
          : _registering
          ? await service.register(
              serverUrl: _serverController.text,
              email: _emailController.text,
              password: _passwordController.text,
              deviceName: 'Android device',
            )
          : await service.login(
              serverUrl: _serverController.text,
              email: _emailController.text,
              password: _passwordController.text,
              deviceName: 'Android device',
            );
      ref.invalidate(storedSessionProvider);
      await _configureBackgroundSyncQuietly(ref);
      if (result.recoveryKey != null && mounted) {
        await _showRecoveryKeyDialog(context, result.recoveryKey!);
      }
      if (!mounted) {
        return;
      }
      await _runSync(context, ref);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on AccountException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message);
      }
    } on Object {
      if (mounted) {
        _showSnackBar(context, 'Could not connect to Recall backup.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _ConnectedBackupPage extends ConsumerWidget {
  const _ConnectedBackupPage({required this.session});

  final StoredSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted backup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              session.account.email,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              session.account.serverUrl,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _runSync(context, ref),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sync now'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).logout();
                try {
                  await ref.read(backgroundSyncControllerProvider).cancel();
                } on Object {
                  // The session is still removed if OS work cancellation fails.
                }
                ref.invalidate(storedSessionProvider);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Disconnect this device'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRecoveryKeyDialog(
  BuildContext context,
  String recoveryKey,
) async {
  var confirmed = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Save your recovery key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'It is the only way to unlock encrypted notes if you lose your password.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              recoveryKey,
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: (value) =>
                  setDialogState(() => confirmed = value ?? false),
              title: const Text('I have stored this key somewhere safe.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: confirmed
                ? () => Navigator.of(dialogContext).pop()
                : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}

class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(trashedNotePreviewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trash')),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(message: error.toString()),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Trash is empty.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _TrashNoteTile(note: items[index]),
              ),
      ),
    );
  }
}

class _TrashNoteTile extends ConsumerWidget {
  const _TrashNoteTile({required this.note});

  final NotePreview note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
      title: Text(
        _noteLabel(note),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: note.title.trim().isEmpty
          ? null
          : Text(
              note.body.isEmpty ? 'Empty note' : note.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore_from_trash_outlined),
            onPressed: () async {
              await ref.read(notesRepositoryProvider).restoreNote(note.id);
              unawaited(_syncQuietly(ref));
              if (context.mounted) {
                _showSnackBar(context, 'Note restored.');
              }
            },
          ),
          IconButton(
            tooltip: 'Delete permanently',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => _confirmPermanentDelete(context, ref, note),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmPermanentDelete(
  BuildContext context,
  WidgetRef ref,
  NotePreview note,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete permanently?'),
      content: Text(
        '"${_noteLabel(note)}" and its reminder will be removed forever.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(reminderSchedulerProvider).cancelNoteReminder(note.id);
    await ref.read(syncServiceProvider).queueDeletion(note.id);
    await ref.read(notesRepositoryProvider).permanentlyDeleteNote(note.id);
    unawaited(_syncQuietly(ref));
  }
}

Future<void> _runSync(BuildContext context, WidgetRef ref) async {
  try {
    final result = await _runTrackedSync(
      ref.read(syncServiceProvider),
      ref.read(backgroundSyncSettingsStoreProvider),
    );
    if (!context.mounted) {
      return;
    }
    if (!result.connected) {
      _showSnackBar(context, 'Connect a backup before syncing.');
      return;
    }
    await _cancelPendingBackgroundSyncQuietly(ref);
    await _reconcileRemindersQuietly(ref);
    if (!context.mounted) {
      return;
    }
    final suffix = result.conflicts > 0
        ? ' ${result.conflicts} conflict${result.conflicts == 1 ? '' : 's'} need review.'
        : '';
    _showSnackBar(
      context,
      'Synced ${result.pushed} change${result.pushed == 1 ? '' : 's'} and received ${result.pulled}.$suffix',
    );
  } on SyncException catch (error) {
    if (context.mounted) {
      _showSnackBar(context, error.message);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Could not sync with Recall backup.');
    }
  }
}

Future<void> _syncQuietly(WidgetRef ref) async {
  await _enqueueBackgroundSyncQuietly(ref);
  try {
    final result = await _runTrackedSync(
      ref.read(syncServiceProvider),
      ref.read(backgroundSyncSettingsStoreProvider),
    );
    if (result.connected) {
      await _cancelPendingBackgroundSyncQuietly(ref);
    }
  } on Object {
    // Local writes stay local-first. The explicit sync action exposes errors.
  } finally {
    await _reconcileRemindersQuietly(ref);
  }
}

Future<void> _configureBackgroundSyncQuietly(WidgetRef ref) async {
  try {
    await ref.read(backgroundSyncControllerProvider).refreshSchedule();
  } on Object {
    // Foreground and manual sync remain available if scheduling fails.
  }
}

Future<void> _enqueueBackgroundSyncQuietly(WidgetRef ref) async {
  try {
    await ref.read(backgroundSyncControllerProvider).enqueueOneOff();
  } on Object {
    // The foreground sync attempt still proceeds.
  }
}

Future<void> _cancelPendingBackgroundSyncQuietly(WidgetRef ref) async {
  try {
    await ref.read(backgroundSyncControllerProvider).cancelPending();
  } on Object {
    // A duplicate fallback sync is safe if cancellation races the OS worker.
  }
}

Future<void> _syncServiceQuietly(
  SyncService service, {
  BackgroundSyncController? backgroundSync,
  BackgroundSyncSettingsStore? diagnostics,
}) async {
  try {
    final result = diagnostics == null
        ? await service.sync()
        : await _runTrackedSync(service, diagnostics);
    if (result.connected) {
      await backgroundSync?.cancelPending();
    }
  } on Object {
    // Local writes stay available when the optional backup is offline.
  }
}

Future<void> _syncAndReconcileQuietly(
  SyncService syncService,
  NotesRepository repository,
  ReminderScheduler scheduler,
  BackgroundSyncController backgroundSync,
  BackgroundSyncSettingsStore diagnostics,
) async {
  await _syncServiceQuietly(
    syncService,
    backgroundSync: backgroundSync,
    diagnostics: diagnostics,
  );
  try {
    final schedules = await repository.loadScheduledReminders();
    await scheduler.reconcileNoteReminders(schedules);
  } on Object {
    // The editor already surfaces direct reminder scheduling failures.
  }
}

Future<SyncResult> _runTrackedSync(
  SyncService service,
  BackgroundSyncSettingsStore diagnostics,
) async {
  try {
    await diagnostics.recordAttempt(DateTime.now());
  } on Object {
    // Diagnostics must never prevent encrypted backup.
  }
  try {
    final result = await service.sync();
    if (result.connected) {
      try {
        await diagnostics.recordSuccess(DateTime.now());
      } on Object {
        // The encrypted data is already synchronized.
      }
    }
    return result;
  } on Object catch (error, stackTrace) {
    try {
      await diagnostics.recordFailure(DateTime.now(), _syncFailureLabel(error));
    } on Object {
      // Preserve the original sync error.
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

String _syncFailureLabel(Object error) {
  if (error is SyncException) {
    return error.message;
  }
  if (error is SocketException) {
    return 'Network unavailable.';
  }
  if (error is TimeoutException) {
    return 'Recall backup timed out.';
  }
  if (error is HttpException) {
    return 'Could not reach Recall backup.';
  }
  return 'Sync could not finish.';
}

String _syncTimeLabel(DateTime? time) {
  if (time == null) {
    return 'Never';
  }
  final now = DateTime.now();
  final difference = now.difference(time);
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }
  final local = time.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

Future<void> _reconcileRemindersQuietly(WidgetRef ref) async {
  try {
    final schedules = await ref
        .read(notesRepositoryProvider)
        .loadScheduledReminders();
    await ref.read(reminderSchedulerProvider).reconcileNoteReminders(schedules);
  } on Object {
    // Individual editor saves still surface scheduling failures directly.
  }
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
    Navigator.of(sheetContext).pop();
    if (update.updateAvailable) {
      await _showUpdateAvailableDialog(rootContext, ref, update);
    } else {
      _showSnackBar(rootContext, 'Recall is up to date.');
    }
  } on UpdateException catch (error) {
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    if (rootContext.mounted) {
      _showSnackBar(rootContext, error.message);
    }
  } on Object {
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
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
        'Recall ${update.latestVersion} is available. You have '
        '${update.currentVersion}${update.downloadSizeBytes == null ? '' : '.\n\nDownload size: ${_formatBytes(update.downloadSizeBytes!)}'}',
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
            progress.value = total == null || total == 0
                ? null
                : received / total;
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

void _showSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

String _noteLabel(NotePreview note) {
  final title = note.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  final body = note.body.trim();
  if (body.isNotEmpty) {
    return body.split('\n').first;
  }
  final firstItem = note.checklistItems.firstOrNull?.text.trim();
  return firstItem == null || firstItem.isEmpty ? 'Untitled note' : firstItem;
}

Future<void> _openNoteEditor(BuildContext context, {String? noteId}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NoteEditorPage(noteId: noteId),
    ),
  );
}

class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

enum _EditorAction { moveToTrash, discard }

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyFocusNode = FocusNode();
  final List<_ChecklistDraft> _checklistItems = [];
  DateTime? _reminderAt;
  ReminderRecurrence _recurrence = ReminderRecurrence.none;
  ColorMood _mood = ColorMood.clear;
  bool _moodWasPicked = false;
  bool _pinned = false;
  bool _isChecklist = false;
  bool _loading = false;
  bool _saving = false;
  bool _missing = false;
  bool _dirty = false;
  bool _hydrating = false;

  bool get _editing => widget.noteId != null;

  @override
  void initState() {
    super.initState();
    _hydrating = _editing;
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
    if (_editing) {
      _loadNote();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _bodyFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    for (final item in _checklistItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() => _loading = true);
    final note = await ref
        .read(notesRepositoryProvider)
        .loadNoteForEditing(widget.noteId!);
    if (!mounted) return;
    if (note == null) {
      setState(() {
        _loading = false;
        _missing = true;
      });
      return;
    }
    _titleController.text = note.title;
    _bodyController.text = note.body;
    _replaceChecklistDrafts(note.checklistItems);
    setState(() {
      _reminderAt = note.reminder?.nextFireAt;
      _recurrence = note.reminder?.recurrence ?? ReminderRecurrence.none;
      _mood = note.mood;
      _moodWasPicked = !note.moodIsAutomatic;
      _pinned = note.pinned;
      _isChecklist = note.checklistItems.isNotEmpty;
      _loading = false;
      _dirty = false;
      _hydrating = false;
    });
  }

  void _onTextChanged() {
    if (_hydrating || !mounted) {
      return;
    }
    setState(() => _dirty = true);
  }

  void _updateDraft(VoidCallback update) {
    setState(() {
      update();
      _dirty = true;
    });
  }

  void _replaceChecklistDrafts(List<ChecklistItemDraft> items) {
    for (final item in _checklistItems) {
      item.dispose();
    }
    _checklistItems
      ..clear()
      ..addAll(items.map(_ChecklistDraft.fromItem));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mood = _moodWasPicked
        ? _mood
        : automaticMoodForNote(
            title: _titleController.text,
            body: _bodyController.text,
            checklistItems: _checklistItems.map((item) => item.controller.text),
            reminder: _reminderAt == null
                ? null
                : NoteReminder(
                    nextFireAt: _reminderAt!,
                    recurrence: _recurrence,
                  ),
          );
    final moodColors = mood.resolve(Theme.of(context).colorScheme);
    final unavailable = _saving || _loading || _missing;

    return PopScope<void>(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_save());
        }
      },
      child: Scaffold(
        backgroundColor: moodColors.background,
        appBar: AppBar(
          backgroundColor: moodColors.background,
          foregroundColor: moodColors.foreground,
          title: Text(_editing ? 'Edit note' : 'New note'),
          actions: [
            IconButton(
              tooltip: _pinned ? 'Unpin note' : 'Pin note',
              onPressed: unavailable
                  ? null
                  : () => _updateDraft(() => _pinned = !_pinned),
              icon: Icon(
                _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
            ),
            PopupMenuButton<_EditorAction>(
              tooltip: 'Note actions',
              enabled: !unavailable,
              onSelected: (action) {
                switch (action) {
                  case _EditorAction.moveToTrash:
                    unawaited(_moveToTrash());
                  case _EditorAction.discard:
                    unawaited(_discardNewNote());
                }
              },
              itemBuilder: (context) => [
                if (_editing)
                  const PopupMenuItem(
                    value: _EditorAction.moveToTrash,
                    child: _MenuItem(
                      icon: Icons.delete_outline_rounded,
                      label: 'Move to trash',
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: _EditorAction.discard,
                    child: _MenuItem(
                      icon: Icons.delete_outline_rounded,
                      label: 'Discard draft',
                    ),
                  ),
              ],
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: moodColors.accent),
              onPressed: unavailable ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Done'),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _missing
              ? const Center(child: Text('This note is no longer available.'))
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  color: moodColors.background,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
                    children: [
                      TextField(
                        key: const Key('note-title-field'),
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        maxLines: 2,
                        style: textTheme.headlineSmall?.copyWith(
                          color: moodColors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Title (optional)',
                          hintStyle: TextStyle(
                            color: moodColors.foreground.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _bodyFocusNode.requestFocus(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('note-body-field'),
                        controller: _bodyController,
                        focusNode: _bodyFocusNode,
                        autofocus: !_editing,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: _isChecklist ? 4 : 12,
                        maxLines: null,
                        style: textTheme.bodyLarge?.copyWith(
                          color: moodColors.foreground,
                          height: 1.45,
                        ),
                        decoration: InputDecoration(
                          hintText: _isChecklist
                              ? 'Add details...'
                              : 'Start writing...',
                          hintStyle: TextStyle(
                            color: moodColors.foreground.withValues(
                              alpha: 0.52,
                            ),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (_reminderAt != null) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InputChip(
                            avatar: Icon(
                              _recurrence == ReminderRecurrence.none
                                  ? Icons.notifications_none_rounded
                                  : Icons.event_repeat_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _formatEditorDateTime(context, _reminderAt!),
                            ),
                            onPressed: _editReminder,
                            onDeleted: () => _updateDraft(() {
                              _reminderAt = null;
                              _recurrence = ReminderRecurrence.none;
                            }),
                            deleteIcon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                      if (_isChecklist) ...[
                        const SizedBox(height: 20),
                        Divider(
                          color: moodColors.foreground.withValues(alpha: 0.16),
                        ),
                        const SizedBox(height: 4),
                        for (
                          var index = 0;
                          index < _checklistItems.length;
                          index++
                        )
                          _ChecklistEditorRow(
                            key: ValueKey(_checklistItems[index]),
                            item: _checklistItems[index],
                            foreground: moodColors.foreground,
                            onChanged: _onChecklistChanged,
                            onSubmitted: () => _advanceChecklist(index),
                            onRemove: () => _removeChecklistItem(index),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: moodColors.accent,
                            ),
                            onPressed: _addChecklistItem,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add item'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: _loading || _missing
            ? null
            : Material(
                color: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: _reminderAt == null
                              ? 'Add reminder'
                              : 'Edit reminder',
                          onPressed: unavailable ? null : _editReminder,
                          icon: Icon(
                            _reminderAt == null
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            color: _reminderAt == null
                                ? null
                                : moodColors.accent,
                          ),
                        ),
                        IconButton(
                          tooltip: _isChecklist
                              ? 'Convert checklist to text'
                              : 'Add checklist',
                          onPressed: unavailable ? null : _toggleChecklist,
                          icon: Icon(
                            Icons.checklist_rounded,
                            color: _isChecklist ? moodColors.accent : null,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Choose colour mood',
                          onPressed: unavailable ? null : _pickMood,
                          icon: Icon(
                            Icons.palette_outlined,
                            color: moodColors.accent,
                          ),
                        ),
                        const Spacer(),
                        if (_moodWasPicked)
                          IconButton(
                            tooltip: 'Use automatic colour',
                            onPressed: unavailable
                                ? null
                                : () => _updateDraft(
                                    () => _moodWasPicked = false,
                                  ),
                            icon: const Icon(Icons.auto_awesome_outlined),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _onChecklistChanged() {
    if (mounted) {
      setState(() => _dirty = true);
    }
  }

  void _addChecklistItem() {
    final item = _ChecklistDraft();
    _updateDraft(() {
      _isChecklist = true;
      _checklistItems.add(item);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        item.focusNode.requestFocus();
      }
    });
  }

  void _advanceChecklist(int index) {
    if (index + 1 < _checklistItems.length) {
      _checklistItems[index + 1].focusNode.requestFocus();
      return;
    }
    _addChecklistItem();
  }

  void _removeChecklistItem(int index) {
    if (index < 0 || index >= _checklistItems.length) {
      return;
    }
    final item = _checklistItems[index];
    _updateDraft(() => _checklistItems.removeAt(index));
    item.dispose();
  }

  void _toggleChecklist() {
    if (!_isChecklist) {
      _addChecklistItem();
      return;
    }

    final lines = _checklistItems
        .where((item) => item.controller.text.trim().isNotEmpty)
        .map(
          (item) =>
              '${item.done ? '[x]' : '[ ]'} ${item.controller.text.trim()}',
        )
        .join('\n');
    _updateDraft(() {
      if (lines.isNotEmpty) {
        final existing = _bodyController.text.trimRight();
        _bodyController.text = existing.isEmpty ? lines : '$existing\n\n$lines';
        _bodyController.selection = TextSelection.collapsed(
          offset: _bodyController.text.length,
        );
      }
      _isChecklist = false;
      for (final item in _checklistItems) {
        item.dispose();
      }
      _checklistItems.clear();
    });
    _bodyFocusNode.requestFocus();
  }

  Future<void> _editReminder() async {
    FocusScope.of(context).unfocus();
    final selection = await _showReminderEditor(
      context,
      initialAt: _reminderAt,
      initialRecurrence: _recurrence,
    );
    if (selection == null || !mounted) {
      return;
    }
    _updateDraft(() {
      _reminderAt = selection.at;
      _recurrence = selection.at == null
          ? ReminderRecurrence.none
          : selection.recurrence;
    });
  }

  Future<void> _pickMood() async {
    FocusScope.of(context).unfocus();
    final selection = await _showMoodPicker(
      context,
      selected: _moodWasPicked ? _mood : null,
    );
    if (selection == null || !mounted) {
      return;
    }
    _updateDraft(() {
      _moodWasPicked = selection.mood != null;
      if (selection.mood != null) {
        _mood = selection.mood!;
      }
    });
  }

  Future<void> _moveToTrash() async {
    final title = _titleController.text.trim();
    final bodyLabel = _bodyController.text.trim().split('\n').firstOrNull ?? '';
    final label = title.isNotEmpty
        ? title
        : bodyLabel.isEmpty
        ? 'Untitled note'
        : bodyLabel;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move note to trash?'),
        content: Text('"$label" can be restored from trash later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final noteId = widget.noteId!;
    final repository = ref.read(notesRepositoryProvider);
    final scheduler = ref.read(reminderSchedulerProvider);
    final syncService = ref.read(syncServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repository.moveNoteToTrash(noteId);
    await scheduler.cancelNoteReminder(noteId);
    _dirty = false;
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Note moved to trash.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              unawaited(
                (() async {
                  try {
                    await repository.restoreNote(noteId);
                    final schedules = await repository.loadScheduledReminders();
                    await scheduler.reconcileNoteReminders(schedules);
                    await _enqueueBackgroundSyncQuietly(ref);
                    await _syncServiceQuietly(
                      syncService,
                      backgroundSync: ref.read(
                        backgroundSyncControllerProvider,
                      ),
                      diagnostics: ref.read(
                        backgroundSyncSettingsStoreProvider,
                      ),
                    );
                  } on Object {
                    // The local restore succeeds even when backup is offline.
                  }
                })(),
              );
            },
          ),
        ),
      );
    unawaited(
      (() async {
        await _enqueueBackgroundSyncQuietly(ref);
        await _syncServiceQuietly(
          syncService,
          backgroundSync: ref.read(backgroundSyncControllerProvider),
          diagnostics: ref.read(backgroundSyncSettingsStoreProvider),
        );
      })(),
    );
  }

  Future<void> _discardNewNote() async {
    final hasContent =
        _titleController.text.trim().isNotEmpty ||
        _bodyController.text.trim().isNotEmpty ||
        _checklistItems.any((item) => item.controller.text.trim().isNotEmpty);
    if (hasContent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard this draft?'),
          content: const Text('This note has not been saved yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    _dirty = false;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final title = _titleController.text;
    final body = _bodyController.text;
    final checklistItems = _isChecklist
        ? _checklistItems.map((item) => item.toModel()).toList()
        : const <ChecklistItemDraft>[];
    if (!_editing &&
        title.trim().isEmpty &&
        body.trim().isEmpty &&
        checklistItems.every((item) => item.text.trim().isEmpty)) {
      _dirty = false;
      Navigator.of(context).pop();
      return;
    }
    final reminder = _reminderAt == null
        ? null
        : NoteReminder(nextFireAt: _reminderAt!, recurrence: _recurrence);
    if (reminder != null &&
        !reminder.repeats &&
        !reminder.nextFireAt.isAfter(DateTime.now())) {
      _showSnackBar(context, 'Choose a future reminder time.');
      return;
    }
    setState(() => _saving = true);
    var reminderProblem = false;
    try {
      final repository = ref.read(notesRepositoryProvider);
      final scheduler = ref.read(reminderSchedulerProvider);
      final syncService = ref.read(syncServiceProvider);
      final noteId = _editing
          ? widget.noteId!
          : await repository.createTextNote(
              title: title,
              body: body,
              mood: _moodWasPicked ? _mood : null,
              pinned: _pinned,
              checklistItems: checklistItems,
              reminder: reminder,
            );
      if (_editing) {
        await repository.updateTextNote(
          id: noteId,
          title: title,
          body: body,
          mood: _moodWasPicked ? _mood : null,
          pinned: _pinned,
          checklistItems: checklistItems,
          reminder: reminder,
        );
      }
      try {
        if (reminder == null) {
          await scheduler.cancelNoteReminder(noteId);
        } else {
          await scheduler.scheduleNoteReminder(
            noteId: noteId,
            title: title,
            body: body,
            reminder: reminder,
          );
        }
      } on Object {
        reminderProblem = true;
      }
      if (mounted) {
        _dirty = false;
        unawaited(
          (() async {
            await _enqueueBackgroundSyncQuietly(ref);
            await _syncAndReconcileQuietly(
              syncService,
              repository,
              scheduler,
              ref.read(backgroundSyncControllerProvider),
              ref.read(backgroundSyncSettingsStoreProvider),
            );
          })(),
        );
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        if (reminderProblem) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Note saved, but the reminder could not be scheduled.',
                ),
              ),
            );
        }
      }
    } on Object {
      if (mounted) {
        _showSnackBar(context, 'Could not save this note.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ChecklistDraft {
  _ChecklistDraft({String text = '', this.done = false})
    : controller = TextEditingController(text: text),
      focusNode = FocusNode();
  _ChecklistDraft.fromItem(ChecklistItemDraft item)
    : this(text: item.text, done: item.done);

  final TextEditingController controller;
  final FocusNode focusNode;
  bool done;

  ChecklistItemDraft toModel() =>
      ChecklistItemDraft(text: controller.text, done: done);
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _ChecklistEditorRow extends StatelessWidget {
  const _ChecklistEditorRow({
    super.key,
    required this.item,
    required this.foreground,
    required this.onChanged,
    required this.onSubmitted,
    required this.onRemove,
  });

  final _ChecklistDraft item;
  final Color foreground;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: item.done,
          onChanged: (value) {
            item.done = value ?? false;
            onChanged();
          },
        ),
        Expanded(
          child: TextField(
            controller: item.controller,
            focusNode: item.focusNode,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmitted(),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              color: foreground,
              decoration: item.done ? TextDecoration.lineThrough : null,
            ),
            decoration: InputDecoration(
              hintText: 'List item',
              hintStyle: TextStyle(color: foreground.withValues(alpha: 0.48)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Remove task',
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
      ],
    );
  }
}

class _ReminderSelection {
  const _ReminderSelection(this.at, this.recurrence);

  final DateTime? at;
  final ReminderRecurrence recurrence;
}

class _MoodSelection {
  const _MoodSelection(this.mood);

  final ColorMood? mood;
}

Future<_ReminderSelection?> _showReminderEditor(
  BuildContext context, {
  required DateTime? initialAt,
  required ReminderRecurrence initialRecurrence,
}) {
  var selectedAt = initialAt ?? _laterToday();
  var recurrence = initialRecurrence;
  final tomorrow = _tomorrowMorning();
  final nextMonday = _nextMondayMorning();

  return showModalBottomSheet<_ReminderSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                initialAt == null ? 'Add reminder' : 'Edit reminder',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text('In one hour'),
                    onPressed: () =>
                        setSheetState(() => selectedAt = _laterToday()),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                    label: const Text('Tomorrow'),
                    onPressed: () => setSheetState(() => selectedAt = tomorrow),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range_outlined, size: 18),
                    label: const Text('Next Monday'),
                    onPressed: () =>
                        setSheetState(() => selectedAt = nextMonday),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(_formatEditorDateTime(sheetContext, selectedAt)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final custom = await _pickReminderDateTime(
                    sheetContext,
                    selectedAt,
                  );
                  if (custom != null && sheetContext.mounted) {
                    setSheetState(() => selectedAt = custom);
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ReminderRecurrence>(
                initialValue: recurrence,
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  prefixIcon: Icon(Icons.event_repeat_rounded),
                ),
                items: [
                  for (final value in ReminderRecurrence.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setSheetState(() => recurrence = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (initialAt != null)
                    TextButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        const _ReminderSelection(null, ReminderRecurrence.none),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      sheetContext,
                    ).pop(_ReminderSelection(selectedAt, recurrence)),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<_MoodSelection?> _showMoodPicker(
  BuildContext context, {
  required ColorMood? selected,
}) {
  return showModalBottomSheet<_MoodSelection>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                'Colour mood',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Automatic'),
              trailing: selected == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () =>
                  Navigator.of(sheetContext).pop(const _MoodSelection(null)),
            ),
            for (final mood in ColorMood.values)
              ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: mood
                        .resolve(Theme.of(sheetContext).colorScheme)
                        .accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                title: Text(_moodLabel(mood)),
                trailing: selected == mood
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_MoodSelection(mood)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<DateTime?> _pickReminderDateTime(
  BuildContext context,
  DateTime initial,
) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(now) ? now : initial,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 3650)),
  );
  if (date == null || !context.mounted) {
    return null;
  }
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime _laterToday() {
  final now = DateTime.now();
  final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
  return nextHour;
}

DateTime _tomorrowMorning() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
}

DateTime _nextMondayMorning() {
  final now = DateTime.now();
  var days = DateTime.monday - now.weekday;
  if (days <= 0) {
    days += 7;
  }
  final monday = now.add(Duration(days: days));
  return DateTime(monday.year, monday.month, monday.day, 9);
}

String _formatEditorDateTime(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(dateTime);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
  return '$date, $time';
}

String _moodLabel(ColorMood mood) {
  return '${mood.name[0].toUpperCase()}${mood.name.substring(1)}';
}
