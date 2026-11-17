import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cms_core/core.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tenantController = TextEditingController(text: 'clinic-sanaa-001');
  ClinicRole _selectedRole = ClinicRole.clinicOwner;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tenantController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).signInWithCredentials(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            tenantId: _tenantController.text.trim(),
            role: _selectedRole,
          );
    } on CmsFailure catch (f) {
      setState(() => _errorMessage = f.arabicMessage);
    } catch (_) {
      setState(() => _errorMessage = 'تعذر إتمام تسجيل الدخول. تحقق من الخادم المحلي أو الشبكة.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'نظام إدارة العيادات الطبية (CMS)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تسجيل الدخول الآمن (متصل / محلي)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_errorMessage!),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _tenantController,
                      decoration: const InputDecoration(labelText: 'معرف العيادة (Tenant ID)'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                      validator: (v) => (v == null || !v.contains('@')) ? 'بريد غير صالح' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة المرور'),
                      validator: (v) => (v == null || v.length < 6) ? '6 أحرف على الأقل' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ClinicRole>(
                      value: _selectedRole,
                      decoration: const InputDecoration(labelText: 'الدور الوظيفي (لبيئة التطوير)'),
                      items: ClinicRole.values
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.arabicLabel)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedRole = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('دخول إلى النظام'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
