import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/notes_presence.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

/// "Sara is editing Diwali shopping" — shown when someone else has a note open.
class LiveBanner extends StatelessWidget {
  const LiveBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final presence = context.watch<NotesPresenceService>();
    final who = presence.activeEditor;
    if (who == null) return const SizedBox.shrink();

    final s = context.read<V3State>();
    final colour = s.memberById(who.userId)?.color ?? Nocturne.accent600;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Nocturne.accent800, width: 1),
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
                Nocturne.mix(Nocturne.accent, 14), Nocturne.surface),
            Nocturne.surface,
          ],
        ),
      ),
      child: Row(
        children: [
          PulsingAvatar(initial: who.initial, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 13,
                        color: Nocturne.text,
                        fontFamily: Nocturne.fontFamily),
                    children: [
                      TextSpan(
                          text: who.name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(text: who.typing ? ' is typing' : ' is editing'),
                    ],
                  ),
                ),
                Text(who.noteTitle ?? 'a note',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Nocturne.neutral400)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Nocturne.accent900,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text('Live',
                style: TextStyle(fontSize: 11, color: Nocturne.accent200)),
          ),
        ],
      ),
    );
  }
}

/// The design's `fnPulse` ring: a dot whose halo expands and fades on a loop.
class PulsingAvatar extends StatefulWidget {
  final String initial;
  final Color color;
  final double size;

  const PulsingAvatar({
    super.key,
    required this.initial,
    required this.color,
    this.size = 30,
  });

  @override
  State<PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size + 4,
        height: widget.size + 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle),
              child: Text(widget.initial,
                  style: TextStyle(
                      fontSize: widget.size * 0.4,
                      fontWeight: FontWeight.w600,
                      color: Nocturne.text)),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  // 0 -> 6px halo that fades out, matching fnPulse.
                  final t = _c.value;
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: NocturneSemantic.income,
                      shape: BoxShape.circle,
                      border: Border.all(color: Nocturne.surface, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: NocturneSemantic.income
                              .withValues(alpha: (1 - t) * 0.6),
                          spreadRadius: 6 * t,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

/// A small green dot used on note cards that someone else currently has open.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: NocturneSemantic.income,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: NocturneSemantic.income
                    .withValues(alpha: (1 - _c.value) * 0.6),
                spreadRadius: 5 * _c.value,
              ),
            ],
          ),
        ),
      );
}

/// The Folders tab: a 2-up grid of folder cards plus a dashed "New folder".
class FolderGrid extends StatelessWidget {
  final ValueChanged<String> onOpen;
  const FolderGrid({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.32,
        children: [
          for (final f in s.folders)
            _FolderCard(
              folder: f,
              count: s.notesInFolder(f.id),
              onTap: () => onOpen(f.id),
            ),
          GestureDetector(
            onTap: () => newFolderDialog(context, s),
            behavior: HitTestBehavior.opaque,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Nocturne.neutral800, width: 1.5),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhRegular.plus, size: 26, color: Nocturne.neutral400),
                  SizedBox(height: 8),
                  Text('New folder',
                      style:
                          TextStyle(fontSize: 13, color: Nocturne.neutral400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> newFolderDialog(BuildContext context, V3State s) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: const Text('New folder',
            style: TextStyle(fontSize: 17, color: Nocturne.text)),
        content: TextField(
          controller: name,
          autofocus: true,
          style: const TextStyle(fontSize: 14, color: Nocturne.text),
          cursorColor: Nocturne.accent,
          decoration: InputDecoration(
            hintText: 'e.g. Wedding, Groceries',
            hintStyle:
                const TextStyle(fontSize: 14, color: Nocturne.neutral600),
            filled: true,
            fillColor: Nocturne.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Nocturne.neutral400))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create',
                  style: TextStyle(color: Nocturne.accent300))),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await s.createFolder(name.text.trim());
    }
  }
}

class _FolderCard extends StatelessWidget {
  final FolderRow folder;
  final int count;
  final VoidCallback onTap;

  const _FolderCard({
    required this.folder,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = V3Design.parseHex(folder.color) ?? Nocturne.accent500;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Nocturne.neutral900, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The design draws a folder: a small tab above a rounded body.
            SizedBox(
              width: 52,
              height: 44,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 24,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                            Colors.black.withValues(alpha: 0.25), colour),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 6,
                    bottom: 0,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colour,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Nocturne.mix(colour, 35),
                              blurRadius: 20,
                              offset: const Offset(0, 8)),
                        ],
                      ),
                      child: const Icon(PhFill.pushPin,
                          size: 16, color: Nocturne.bg),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Nocturne.text)),
            const SizedBox(height: 2),
            Text('$count note${count == 1 ? '' : 's'}',
                style:
                    const TextStyle(fontSize: 11.5, color: Nocturne.neutral500)),
          ],
        ),
      ),
    );
  }
}

/// The folder filter chip shown above the list when a folder is open.
class FolderChip extends StatelessWidget {
  final FolderRow folder;
  final VoidCallback onClear;

  const FolderChip({super.key, required this.folder, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colour = V3Design.parseHex(folder.color) ?? Nocturne.accent300;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onClear,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Nocturne.accent900,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Nocturne.accent600, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhFill.pushPin, size: 12, color: colour),
                const SizedBox(width: 6),
                Text(folder.name,
                    style: const TextStyle(
                        fontSize: 12, color: Nocturne.accent100)),
                const SizedBox(width: 6),
                const Icon(PhRegular.x, size: 11, color: Nocturne.accent200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
