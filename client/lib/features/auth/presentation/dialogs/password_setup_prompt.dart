import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../cubit/app_session_cubit.dart';
import '../../data/auth_repository.dart';

class PasswordSetupPromptDialog extends StatefulWidget {
  const PasswordSetupPromptDialog({
    super.key,
    required this.repository,
    required this.appSessionCubit,
  });

  final AuthRepository repository;
  final AppSessionCubit appSessionCubit;

  @override
  State<PasswordSetupPromptDialog> createState() =>
      _PasswordSetupPromptDialogState();
}

class _PasswordSetupPromptDialogState extends State<PasswordSetupPromptDialog> {
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _inlineError = '请输入登录密码';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      await widget.repository.setPassword(newPassword: password);
      widget.appSessionCubit.markPasswordPromptHandled();
      await widget.appSessionCubit.refreshProfile();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on AuthMissingTokenException {
      await widget.appSessionCubit.logout();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await widget.appSessionCubit.logout();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = _readErrorMessage(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = '设置密码失败，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _skip() {
    widget.appSessionCubit.markPasswordPromptHandled();
    Navigator.of(context).pop();
  }

  String _readErrorMessage(DioException error) {
    final payload = error.response?.data;
    if (payload is Map && payload['message'] is String) {
      return payload['message'] as String;
    }
    return error.message ?? '设置密码失败，请稍后重试';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置登录密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前账号还没有登录密码，建议现在补充，方便下次直接使用密码登录。',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '新密码',
              border: OutlineInputBorder(),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 12),
            Text(
              _inlineError!,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : _skip,
          child: const Text('稍后设置'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? '设置中...' : '立即设置'),
        ),
      ],
    );
  }
}
