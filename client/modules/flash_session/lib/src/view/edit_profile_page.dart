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
          appBar: AppBar(title: const Text('个人资料')),
          backgroundColor: const Color(0xFFF6F7F9),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SectionCard(
                children: [
                  _ProfileRow(
                    label: '头像',
                    value: '查看并随机更换',
                    leading: UserAvatar(user: user, size: 48),
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
                      onSubmit: (value) => _applyUpdate(context, nickname: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                children: [
                  _ProfileRow(label: '手机号', value: _maskPhone(user.phone)),
                  _ProfileRow(label: '闪讯号', value: '${user.userId}'),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                children: [
                  _ProfileRow(
                    label: '签名',
                    value: user.signature.trim().isEmpty ? '添加个性签名' : user.signature,
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
      MaterialPageRoute(
        builder: (_) => _AvatarEditPage(initialUser: user),
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final seed = '${widget.initialUser.userId}-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(9999)}';
    setState(() {
      _avatarValue = 'identicon:$seed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewUser = widget.initialUser.copyWith(avatar: _avatarValue);
    return Scaffold(
      appBar: AppBar(title: const Text('修改头像')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              UserAvatar(user: previewUser, size: 120),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _shuffle,
                child: const Text('随机更换'),
              ),
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
    required this.value,
    this.leading,
    this.onTap,
  });

  final String label;
  final String value;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2A42),
              ),
            ),
          ),
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6A7B92),
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF98A7BA),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(onTap: onTap, child: content);
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
        rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      rows.add(children[i]);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: rows),
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
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
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLines: widget.maxLines,
                minLines: widget.maxLines,
                decoration: InputDecoration(
                  labelText: widget.label,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _inlineError!,
                  style: const TextStyle(color: Color(0xFFE35D6A), fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
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
