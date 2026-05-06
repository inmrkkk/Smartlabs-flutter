import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'profile_setup.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacyPolicy = false;

  @override
  void dispose() {
    // Clean up controllers
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Validate and handle registration
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms || !_acceptedPrivacyPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept both the Terms and Conditions and Privacy Policy to continue',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProfileSetupPage(
                pendingName: name,
                pendingEmail: email,
                pendingPassword: password,
              ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                child: _buildForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // App header with logo
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF2AA39F),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(100),
          bottomRight: Radius.circular(100),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.science, size: 100, color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              'SMARTLAB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Registration form
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          const Row(
            children: [
              Text(
                'REGISTER ',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Name field
          _buildInputField(
            label: 'Full Name',
            controller: _nameController,
            hintText: 'Your full name',
            keyboardType: TextInputType.name,
            validator:
                (value) => value!.isEmpty ? 'Please enter your name' : null,
          ),

          // Email field
          _buildInputField(
            label: 'Email address',
            controller: _emailController,
            hintText: 'your.email@dnsc.edu.ph',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value!.isEmpty) return 'Please enter your email';
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Please enter a valid email';
              }
              if (!value.endsWith('@dnsc.edu.ph')) {
                return 'Only @dnsc.edu.ph email addresses are allowed';
              }
              return null;
            },
          ),

          // Password field
          _buildInputField(
            label: 'Password',
            controller: _passwordController,
            hintText: 'Password',
            obscureText: _obscurePassword,
            validator:
                (value) =>
                    value!.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          // Terms and Conditions
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _acceptedTerms,
                  onChanged: (value) => setState(() => _acceptedTerms = value!),
                  activeColor: const Color(0xFF52B788),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _showTermsAndConditions,
                  child: RichText(
                    text: TextSpan(
                      text: 'I agree to the ',
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Terms and Conditions',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Privacy Policy
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _acceptedPrivacyPolicy,
                  onChanged:
                      (value) => setState(() => _acceptedPrivacyPolicy = value!),
                  activeColor: const Color(0xFF52B788),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _showPrivacyPolicy,
                  child: RichText(
                    text: TextSpan(
                      text: 'I agree to the ',
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Sign up button
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF52B788),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                    : const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),

          const SizedBox(height: 20),

          // Login text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Already have an account? "),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Login',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Terms and Conditions'),
            content: const SingleChildScrollView(
              child: Text(
                'Welcome to SMARTLAB. By using this application, you agree to the following terms:\n\n'
                '1. Account Security: You are responsible for maintaining the confidentiality of your account credentials.\n\n'
                '2. Acceptable Use: You agree to use this application and laboratory equipment only for authorized academic and research purposes.\n\n'
                '3. Liability: SMARTLAB is not liable for damages resulting from improper or unauthorized use of laboratory equipment or the application.\n\n'
                '4. Data Privacy: Your institutional email (@dnsc.edu.ph) and related user data are collected and used for authentication, system access, and academic record-keeping purposes only, in accordance with applicable data privacy laws such as the Data Privacy Act of 2012. For more details, please refer to the Privacy Policy.\n\n'
                '5. Compliance: Users must follow all laboratory safety protocols and institutional guidelines when borrowing equipment.\n\n'
                'By checking the box, you acknowledge that you have read, understood, and agreed to these Terms and Conditions.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _acceptedTerms = true);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF52B788),
                  foregroundColor: Colors.white,
                ),
                child: const Text('I Agree'),
              ),
            ],
          ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Privacy Policy'),
            content: const SingleChildScrollView(
              child: Text(
                'Welcome to SMARTLAB Mobile Application. This Privacy Policy explains how we collect, use, and protect your personal information when you use the app as a Student or Instructor.\n\n'
                '1. Scope of the Mobile Application\n'
                'The SMARTLAB Mobile Application is used by:\n'
                'Students – to request and borrow laboratory equipment\n'
                'Instructors – to approve student equipment requests and borrow equipment for academic purposes\n'
                'Instructors are not responsible for monitoring overall equipment usage within the system.\n\n'
                '2. Information We Collect\n'
                'When using the SMARTLAB Mobile Application, we collect:\n'
                'Institutional email address (@dnsc.edu.ph)\n'
                'Name and role (Student or Instructor)\n'
                'Equipment borrowing records\n'
                'Equipment request data\n'
                'Approval records (for instructor actions)\n'
                'Basic system activity logs (e.g., login and transactions)\n\n'
                '3. How We Use Your Information\n'
                'Your information is used for:\n'
                'User authentication and secure access\n'
                'Processing equipment borrowing requests\n'
                'Allowing instructors to approve or reject student requests\n'
                'Recording borrowing transactions and request history\n'
                'Ensuring proper tracking of laboratory equipment usage for academic purposes\n'
                'Improving system performance and reliability\n\n'
                '4. Data Protection\n'
                'SMARTLAB ensures that all collected data is:\n'
                'Stored securely using appropriate security measures\n'
                'Accessible only to authorized users based on their roles\n'
                'Protected against unauthorized access, modification, or disclosure\n\n'
                '5. Data Sharing\n'
                'Your personal data is:\n'
                'Not sold or shared with third parties\n'
                'Only disclosed if required by law or institutional policies\n\n'
                '6. Data Retention\n'
                'Data is retained only as long as necessary for academic and system purposes and may be archived or deleted based on institutional policies.\n\n'
                '7. User Rights\n'
                'Under the Data Privacy Act of 2012, users have the right to:\n'
                'Access their personal data\n'
                'Request correction of inaccurate information\n'
                'Request deletion of data (subject to institutional rules)\n'
                'Be informed how their data is processed\n\n'
                '8. Institutional Email Requirement\n'
                'Only official institutional emails (@dnsc.edu.ph) are used to ensure secure and verified access to the system.\n\n'
                '9. Policy Updates\n'
                'SMARTLAB may update this Privacy Policy when necessary. Users will be notified of any significant changes through the application.\n\n'
                '10. Contact Information\n'
                'For concerns or inquiries about this Privacy Policy, users may contact the system administrator or the institution’s data privacy officer.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _acceptedPrivacyPolicy = true);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF52B788),
                  foregroundColor: Colors.white,
                ),
                child: const Text('I Agree'),
              ),
            ],
          ),
    );
  }

  // Reusable input field component
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[200],
            suffixIcon: suffixIcon,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
