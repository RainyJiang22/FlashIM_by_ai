import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

class GroupAnnouncementPage extends StatefulWidget {
  const GroupAnnouncementPage({
    super.key,
    required this.announcement,
    required this.canEdit,
    required this.updatedByName,
    required this.updatedAt,
    required this.onPublish,
  });

  final String announcement;
  final bool canEdit;
  final String updatedByName;
  final DateTime? updatedAt;
  final Future<bool> Function(String value) onPublish;

  @override
  State<GroupAnnouncementPage> createState() => _GroupAnnouncementPageState();
}

class _GroupAnnouncementPageState extends State<GroupAnnouncementPage> {
  late final TextEditingController _controller;
  var _isEditing = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.announcement);
    _isEditing = widget.canEdit && widget.announcement.isEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群公告'),
        actions: [
          if (widget.canEdit)
            TextButton(
              key: const Key('group-announcement-action'),
              onPressed: _isSaving
                  ? null
                  : _isEditing
                  ? _publish
                  : () => setState(() => _isEditing = true),
              child: Text(_isEditing ? '发布' : '编辑'),
            ),
        ],
      ),
      backgroundColor: FlashPalette.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isEditing ? _editor() : _content(),
      ),
    );
  }

  Widget _editor() => TextField(
    key: const Key('group-announcement-input'),
    controller: _controller,
    autofocus: true,
    maxLength: 2000,
    minLines: 8,
    maxLines: null,
    decoration: const InputDecoration(
      hintText: '请输入群公告',
      filled: true,
      fillColor: FlashPalette.surface,
      alignLabelWithHint: true,
    ),
  );

  Widget _content() {
    if (widget.announcement.isEmpty) {
      return const Center(
        child: Text(
          '暂无群公告',
          key: Key('group-announcement-empty'),
          style: TextStyle(color: FlashPalette.secondaryInk),
        ),
      );
    }
    final updatedAt = widget.updatedAt;
    final subtitle = [
      if (widget.updatedByName.trim().isNotEmpty) widget.updatedByName,
      if (updatedAt != null)
        '${updatedAt.year}-${_two(updatedAt.month)}-${_two(updatedAt.day)} '
            '${_two(updatedAt.hour)}:${_two(updatedAt.minute)}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: flashCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.announcement,
            key: const Key('group-announcement-content'),
            style: const TextStyle(
              color: FlashPalette.ink,
              fontSize: 16,
              height: 1.6,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: const TextStyle(
                color: FlashPalette.secondaryInk,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _publish() async {
    final value = _controller.text.trim();
    if (value.isEmpty || value.runes.length > 2000 || _isSaving) return;
    setState(() => _isSaving = true);
    final saved = await widget.onPublish(value);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) Navigator.of(context).pop();
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
