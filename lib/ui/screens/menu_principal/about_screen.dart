import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:ada_app/services/api/auth_service.dart';

// Since package_info_plus is not in pubspec, I will create a simple version.
// If the user wants dynamic versioning, they can request the package addition.
// For now I will hardcode or use a helper.

import 'package:ada_app/config/app_config.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = AppConfig.currentAppVersion;
  String _buildNumber = '1';
  Usuario? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();

      // Simulate version loading since we don't have package_info_plus yet
      // In a real scenario with the package:
      // final packageInfo = await PackageInfo.fromPlatform();
      // _version = packageInfo.version;
      // _buildNumber = packageInfo.buildNumber;

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Acerca de', style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.containerBackground, AppColors.background],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildAppLogo(),
                    SizedBox(height: 32),
                    _buildInfoCard(),
                    SizedBox(height: 24),
                    _buildVersionInfo(),
                    SizedBox(height: 48),
                    // _buildCopyright(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset('assets/logo_bdp.png', fit: BoxFit.contain),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'AdaApp',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Usuario',
              value: _currentUser?.username ?? 'No disponible',
            ),
            Divider(height: 24),
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'Employee Name',
              value: _currentUser?.employeeName ?? 'No asignado',
            ),
            Divider(height: 24),
            _buildInfoRow(
              icon: Icons.verified_user_outlined,
              label: 'ID Employee',
              value: _currentUser?.employeeId ?? 'No asignado',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Column(
      children: [
        Text(
          'Versión $_version (Build $_buildNumber)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Actualizado',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildCopyright() {
  //   return Text(
  //     '© ${DateTime.now().year} Alar Software.\nTodos los derechos reservados.',
  //     textAlign: TextAlign.center,
  //     style: TextStyle(
  //       color: AppColors.textSecondary.withValues(alpha: 0.6),
  //       fontSize: 12,
  //     ),
  //   );
  // }
}
