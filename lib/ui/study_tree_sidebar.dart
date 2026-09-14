import 'package:flutter/material.dart';
import 'package:chess_repertoire_srs/domain/entities/chapter.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/study.dart';

/// Read-only Listudy-inspired study tree sidebar component with node selection for preview
class StudyTreeSidebar extends StatelessWidget {
  const StudyTreeSidebar({
    super.key,
    required this.studies,
    required this.selectedStudyId,
    required this.currentNodeId,
    required this.previewNodeId,
    required this.onStudySelected,
    required this.onNodeSelected,
    required this.repository,
  });

  final List<Study> studies;
  final String? selectedStudyId;
  final String? currentNodeId;
  final String? previewNodeId;
  final ValueChanged<String?> onStudySelected;
  final ValueChanged<PositionNode> onNodeSelected;
  final dynamic repository; // StudyRepository

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF1E1D1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF262421),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Repertoire Tree',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                DropdownButton<String?>(
                  value: selectedStudyId,
                  dropdownColor: const Color(0xFF262421),
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Studies'),
                    ),
                    for (final s in studies)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.title, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: onStudySelected,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final study in studies)
                  if (selectedStudyId == null || selectedStudyId == study.id)
                    _StudySection(
                      study: study,
                      currentNodeId: currentNodeId,
                      previewNodeId: previewNodeId,
                      onNodeSelected: onNodeSelected,
                      repository: repository,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudySection extends StatefulWidget {
  const _StudySection({
    required this.study,
    required this.currentNodeId,
    required this.previewNodeId,
    required this.onNodeSelected,
    required this.repository,
  });

  final Study study;
  final String? currentNodeId;
  final String? previewNodeId;
  final ValueChanged<PositionNode> onNodeSelected;
  final dynamic repository;

  @override
  State<_StudySection> createState() => _StudySectionState();
}

class _StudySectionState extends State<_StudySection> {
  List<Chapter> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    final chapters = await widget.repository.getChaptersByStudy(widget.study.id);
    if (mounted) {
      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_chapters.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            widget.study.title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF81B64C)),
          ),
        ),
        for (final chapter in _chapters)
          _ChapterItem(
            chapter: chapter,
            currentNodeId: widget.currentNodeId,
            previewNodeId: widget.previewNodeId,
            onNodeSelected: widget.onNodeSelected,
          ),
      ],
    );
  }
}

class _ChapterItem extends StatefulWidget {
  const _ChapterItem({
    required this.chapter,
    required this.currentNodeId,
    required this.previewNodeId,
    required this.onNodeSelected,
  });

  final Chapter chapter;
  final String? currentNodeId;
  final String? previewNodeId;
  final ValueChanged<PositionNode> onNodeSelected;

  @override
  State<_ChapterItem> createState() => _ChapterItemState();
}

class _ChapterItemState extends State<_ChapterItem> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final root = widget.chapter.root;
    final title = widget.chapter.title ?? 'Chapter';
    return ExpansionTile(
      initiallyExpanded: _expanded,
      onExpansionChanged: (val) => setState(() => _expanded = val),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, color: Colors.white),
      ),
      leading: const Icon(Icons.bookmark_outline, size: 16, color: Colors.grey),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 16),
      children: [
        if (root != null)
          for (final child in root.children)
            _TreeNodeWidget(
              node: child,
              currentNodeId: widget.currentNodeId,
              previewNodeId: widget.previewNodeId,
              onNodeSelected: widget.onNodeSelected,
              moveNumber: 1,
              isWhite: true,
            ),
      ],
    );
  }
}

class _TreeNodeWidget extends StatelessWidget {
  const _TreeNodeWidget({
    required this.node,
    required this.currentNodeId,
    required this.previewNodeId,
    required this.onNodeSelected,
    required this.moveNumber,
    required this.isWhite,
  });

  final PositionNode node;
  final String? currentNodeId;
  final String? previewNodeId;
  final ValueChanged<PositionNode> onNodeSelected;
  final int moveNumber;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    final move = node.incomingMove;
    final san = move?.san ?? '...';
    final isCurrent = node.id == currentNodeId;
    final isPreview = node.id == previewNodeId;

    final moveLabel = isWhite ? '$moveNumber. $san' : '$san';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onNodeSelected(node),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isPreview
                  ? const Color(0xFFE5C07B).withValues(alpha: 0.3)
                  : isCurrent
                      ? const Color(0xFF629924).withValues(alpha: 0.3)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isPreview
                  ? Border.all(color: const Color(0xFFE5C07B), width: 1)
                  : isCurrent
                      ? Border.all(color: const Color(0xFF629924), width: 1)
                      : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  moveLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPreview || isCurrent ? Colors.white : Colors.white70,
                    fontWeight: isPreview || isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (node.comment != null && node.comment!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.comment, size: 10, color: Colors.amber),
                ],
              ],
            ),
          ),
        ),
        if (node.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in node.children)
                  _TreeNodeWidget(
                    node: child,
                    currentNodeId: currentNodeId,
                    previewNodeId: previewNodeId,
                    onNodeSelected: onNodeSelected,
                    moveNumber: isWhite ? moveNumber : moveNumber + 1,
                    isWhite: !isWhite,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
