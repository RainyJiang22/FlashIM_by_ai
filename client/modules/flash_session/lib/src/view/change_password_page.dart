import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/session_repository.dart';
import '../logic/session_cubit.dart';
import 'set_password_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  late final TextEditingController _oldPasswordController;
  late final TextEditingController _newPasswordController;
  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    if (oldPassword.isEmpty || newPassword.isEmpty) {
      setState(() {
        _inlineError = '请输入旧密码和新密码';
      });
      return;
    }
    if (newPassword.length < 6) {
      setState(() {
        _inlineError = '新密码至少需要 6 位';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      await context.read<SessionCubit>().changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on SessionMissingTokenException {
      await context.read<SessionCubit>().logout();
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = error.response?.statusCode == 401
            ? '旧密码错误'
            : readSessionDioErrorMessage(
                error,
                fallback: '修改密码失败，请稍后重试',
              );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = '修改密码失败，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改密码')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            TextField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '旧密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
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
                style: const TextStyle(color: Color(0xFFE35D6A), fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(_isSubmitting ? '保存中...' : '完成'),
            ),
          ],
        ),
      ),
    );
  }
}
