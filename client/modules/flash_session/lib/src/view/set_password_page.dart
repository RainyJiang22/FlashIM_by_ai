import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/session_repository.dart';
import '../logic/session_cubit.dart';

class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
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
    if (password.length < 6) {
      setState(() {
        _inlineError = '密码至少需要 6 位';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      await context.read<SessionCubit>().setPassword(newPassword: password);
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
        _inlineError = readSessionDioErrorMessage(
          error,
          fallback: '设置密码失败，请稍后重试',
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(title: const Text('设置密码')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE4EAF3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF2C6BED),
                    size: 28,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '为账号设置一个密码，之后可以直接使用密码登录。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF72809A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE4EAF3)),
              ),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码'),
              ),
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 12),
              Text(
                _inlineError!,
                style: const TextStyle(color: Color(0xFFD95D6A), fontSize: 13),
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

String readSessionDioErrorMessage(
  DioException error, {
  required String fallback,
}) {
  final payload = error.response?.data;
  if (payload is Map && payload['message'] is String) {
    return payload['message'] as String;
  }
  return error.message ?? fallback;
}
