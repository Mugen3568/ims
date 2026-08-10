import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _childEmailController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _scrollController = ScrollController();

  // ── State ────────────────────────────────────────────────────────────────────
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  // Role selection: Explicitly supports all 5 roles
  String _selectedRole = 'student';
  final List<String> _roles = ['student', 'parent', 'teacher', 'manager', 'owner'];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _childEmailController.dispose();
    _inviteCodeController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Submit ───────────────────────────────────────────────────────────────────
  void _submit(AuthService authService) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String? error;

      if (_isRegistering) {
        error = await authService.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _selectedRole,
          _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          childEmail: _selectedRole == 'parent'
              ? _childEmailController.text.trim()
              : null,
          inviteCode: _selectedRole == 'student'
              ? _inviteCodeController.text.trim()
              : null,
          assignedClasses: null,
        );

        if (mounted && error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '✅ Registration successful! Check your email to verify.',
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          setState(() {
            _isRegistering = false;
          });
        }
      } else {
        error = await authService.loginWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }

      if (mounted && error != null) {
        setState(() {
          _errorMessage = error!;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  void _switchMode() {
    _animController.reset();
    setState(() {
      _isRegistering = !_isRegistering;
      _errorMessage = '';
      _inviteCodeController.clear();
      _childEmailController.clear();
      _selectedRole = 'student';
    });
    _animController.forward();
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icons.admin_panel_settings_rounded;
      case 'manager':
        return Icons.manage_accounts_rounded;
      case 'teacher':
        return Icons.school_rounded;
      case 'parent':
        return Icons.family_restroom_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF050505), const Color(0xFF0A1628)]
                : [const Color(0xFFF0F4FF), const Color(0xFFF8F9FA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(isDark),
                      const SizedBox(height: 32),
                      _buildCard(context, isDark, authService, theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        // Logo / icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'IMS Portal',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D47A1),
          ),
        ),
        Text(
          _isRegistering ? 'Create your account' : 'Welcome back',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    bool isDark,
    AuthService authService,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Registration-only fields ──────────────────────────────────────
          if (_isRegistering) ...[
            _buildField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _phoneController,
              label: 'Phone Number (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildRolePicker(isDark),
            const SizedBox(height: 16),
          ],

          // ── Email ─────────────────────────────────────────────────────────
          _buildField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // ── Password ─────────────────────────────────────────────────────
          _buildField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 16),

          // ── Role-specific fields ────────────────────────────────────
          if (_isRegistering) ...[
            if (_selectedRole == 'student') ...[
              _buildField(
                controller: _inviteCodeController,
                label: 'Class Invite Code',
                hintText: 'e.g. BCA3A-K83XQ',
                icon: Icons.vpn_key_rounded,
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedRole == 'parent') ...[
              _buildField(
                controller: _childEmailController,
                label: "Child's Email Address or Student ID",
                hintText: 'Enter student email or ID',
                icon: Icons.child_care_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedRole == 'teacher') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
                  ),
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.06),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF0D47A1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your classes will be assigned by an Owner or Manager after your account is approved.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],

          // ── Error message ─────────────────────────────────────────────────
          if (_errorMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Submit button ─────────────────────────────────────────────────
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _submit(authService),
                  child: Text(_isRegistering ? 'Create Account' : 'Sign In'),
                ),
          const SizedBox(height: 12),

          // ── Toggle link ───────────────────────────────────────────────────
          TextButton(
            onPressed: _switchMode,
            child: Text(
              _isRegistering
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Register",
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Role picker chips ─────────────────────────────────────────────────────────
  Widget _buildRolePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am a...',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _roles.map((role) {
            final isSelected = _selectedRole == role;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRole = role;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0D47A1)
                      : (isDark
                            ? Colors.grey[850]
                            : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0D47A1)
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _roleIcon(role),
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      role[0].toUpperCase() + role.substring(1),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }



  // ── Helper field widgets ──────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
