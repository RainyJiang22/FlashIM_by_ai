import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/session_repository.dart';
import '../data/user.dart';
import '../logic/session_cubit.dart';
import '../logic/session_state.dart';
import 'set_password_page.dart';
import 'widget/user_card.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        final user = state.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: _ProfileAppBar(title: '个人资料'),
          backgroundColor: const Color(0xFFF1F1F1),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 1),
              _SectionCard(
                children: [
                  _ProfileRow(
                    label: '头像',
                    trailing: UserAvatar(user: user, size: 56),
                    onTap: () => _editAvatar(context, user),
                  ),
                  _ProfileRow(
                    label: '名字',
                    value: user.nickname,
                    onTap: () => _editText(
                      context,
                      title: '修改名字',
                      label: '名字',
                      initialValue: user.nickname,
                      onSubmit: (value) =>
                          _applyUpdate(context, nickname: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                children: [
                  _ProfileRow(label: '手机号', value: _maskPhone(user.phone)),
                  _ProfileRow(label: '闪讯号', value: '${user.userId}'),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                children: [
                  _ProfileRow(
                    label: '签名',
                    value: user.signature.trim().isEmpty
                        ? '添加个性签名'
                        : user.signature,
                    maxLines: 2,
                    onTap: () => _editText(
                      context,
                      title: '修改签名',
                      label: '签名',
                      initialValue: user.signature,
                      maxLines: 3,
                      onSubmit: (value) =>
                          _applyUpdate(context, signature: value.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyUpdate(
    BuildContext context, {
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    try {
      await context.read<SessionCubit>().updateProfile(
        nickname: nickname,
        signature: signature,
        avatar: avatar,
      );
    } on SessionMissingTokenException {
      await context.read<SessionCubit>().logout();
    } on DioException catch (error) {
      _showError(
        context,
        readSessionDioErrorMessage(error, fallback: '保存失败，请稍后重试'),
      );
    } catch (_) {
      _showError(context, '保存失败，请稍后重试');
    }
  }

  Future<void> _editAvatar(BuildContext context, User user) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _AvatarEditPage(initialUser: user)),
    );

    if (result == null || !context.mounted) {
      return;
    }
    await _applyUpdate(context, avatar: result);
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String label,
    required String initialValue,
    required Future<void> Function(String value) onSubmit,
    int maxLines = 1,
  }) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _TextEditPage(
          title: title,
          label: label,
          initialValue: initialValue,
          maxLines: maxLines,
        ),
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }
    await onSubmit(result.trim());
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) {
      return phone;
    }
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AvatarEditPage extends StatefulWidget {
  const _AvatarEditPage({required this.initialUser});

  final User initialUser;

  @override
  State<_AvatarEditPage> createState() => _AvatarEditPageState();
}

class _AvatarEditPageState extends State<_AvatarEditPage> {
  late String _avatarValue;

  @override
  void initState() {
    super.initState();
    _avatarValue = widget.initialUser.avatar;
  }

  void _shuffle() {
    final random = Random();
    final seed =
        '${widget.initialUser.userId}-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(9999)}';
    setState(() {
      _avatarValue = 'identicon:$seed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewUser = widget.initialUser.copyWith(avatar: _avatarValue);
    return Scaffold(
      appBar: _ProfileAppBar(title: '修改头像'),
      backgroundColor: const Color(0xFFF1F1F1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              UserAvatar(user: previewUser, size: 120),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: _shuffle, child: const Text('随机更换')),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_avatarValue),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    this.value = '',
    this.trailing,
    this.onTap,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 19,
                height: 1.15,
                color: Color(0xFF191919),
              ),
            ),
          ),
          Expanded(
            child: value.isEmpty
                ? const SizedBox.shrink()
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.22,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFC7C7C7),
              size: 28,
            ),
          ],
        ],
      ),
    );

    final row = SizedBox(
      height: trailing == null && maxLines == 1 ? 64 : 82,
      child: content,
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(onTap: onTap, child: row);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 1) {
      if (i > 0) {
        rows.add(
          const Divider(height: 1, indent: 22, color: Color(0xFFEDEDED)),
        );
      }
      rows.add(children[i]);
    }

    return Material(
      color: Colors.white,
      child: Column(children: rows),
    );
  }
}

class _ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileAppBar({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      backgroundColor: const Color(0xFFEDEDED),
      surfaceTintColor: Colors.transparent,
      foregroundColor: const Color(0xFF191919),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded, size: 36),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111111),
        ),
      ),
      actions: [
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: action),
          ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(60, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: Colors.white,
        disabledForegroundColor: const Color(0xFFBFBFBF),
        backgroundColor: enabled
            ? const Color(0xFF07C160)
            : const Color(0xFFE5E5E5),
        disabledBackgroundColor: const Color(0xFFE5E5E5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      child: const Text('保存'),
    );
  }
}

class _TextEditPage extends StatefulWidget {
  const _TextEditPage({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.maxLines,
  });

  final String title;
  final String label;
  final String initialValue;
  final int maxLines;

  @override
  State<_TextEditPage> createState() => _TextEditPageState();
}

class _TextEditPageState extends State<_TextEditPage> {
  late final TextEditingController _controller;
  String? _inlineError;

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() {
      setState(() {
        _inlineError = null;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _inlineError = '${widget.label}不能为空';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ProfileAppBar(
        title: widget.title,
        action: _SaveButton(enabled: _canSubmit, onPressed: _submit),
      ),
      backgroundColor: const Color(0xFFF1F1F1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: widget.maxLines,
                minLines: widget.maxLines,
                cursorColor: const Color(0xFF07C160),
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.25,
                  color: Color(0xFF191919),
                ),
                decoration: const InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF07C160)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF07C160)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFF07C160),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _inlineError!,
                  style: const TextStyle(
                    color: Color(0xFFE64340),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
