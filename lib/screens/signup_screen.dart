import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  // emailController가 전체 이메일 주소를 받도록 함
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  int _selectedAge = 20;
  String _gender = '남';
  bool _isPasswordVisible = false;

  // 나이 선택 BottomSheet
  void _selectAge(BuildContext context) {
    final FixedExtentScrollController scrollController =
    FixedExtentScrollController(initialItem: _selectedAge - 1);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
          child: Column(
            children: [
              Text(
                '나이를 선택해주세요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
              ),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  controller: scrollController,
                  itemExtent: 50,
                  perspective: 0.003,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      final age = index + 1;
                      return Center(
                        child: Text(
                          '$age세',
                          style: const TextStyle(fontSize: 20),
                        ),
                      );
                    },
                    childCount: 120,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _selectedAge = scrollController.selectedItem + 1;
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('확인'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // 회원가입 로직
  Future<void> _submit() async {
    if(!mounted) return;

    final String name = _nameController.text.trim();
    // 사용자가 입력한 전체 이메일 주소를 사용
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필수 정보를 입력해주세요.')),
      );
      return;
    }

    // 이메일 유효성 검사
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 이메일 주소를 입력해주세요.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호는 6자 이상 입력해주세요.')),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Firestore에 사용자 정보 저장
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'age': _selectedAge,
          'gender': _gender,
          'email': email,
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해주세요.')),
          );
          // 회원가입 성공 후 로그인 화면으로 이동
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()), // const 추가
                (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = '회원가입 오류: ${e.message ?? '알 수 없는 오류'}'; // e.message가 null일 수 있음
      if (e.code == 'weak-password') {
        errorMessage = '비밀번호가 너무 약합니다. (6자 이상)';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = '이미 가입된 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        errorMessage = '유효하지 않은 이메일 형식입니다.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = '너무 많은 요청을 보냈습니다. 잠시 후 다시 시도해주세요.';
      }
      debugPrint('Firebase Auth Error (Signup): ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      debugPrint('Generic Error (Signup): ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알 수 없는 오류가 발생했습니다: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMUnity Rest Place 회원가입'), // const
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '환영합니다!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor, // 테마 색상 활용
                  ),
                ),
                Text(
                  '서비스 이용을 위해 정보를 입력해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 32),

                // 이름 입력
                _buildLabel('이름'),
                TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  decoration: _inputDecoration(hintText: '이름 입력', icon: Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),

                // 이메일 입력 필드
                _buildLabel('이메일 주소'), // Label
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress, // KeyboardType
                  decoration: _inputDecoration(hintText: '이메일 주소 입력', icon: Icons.email_outlined), // Icon
                  autocorrect: false,
                ),
                const SizedBox(height: 20),

                // 비밀번호 입력
                _buildLabel('비밀번호'),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: _inputDecoration(hintText: '비밀번호 (6자 이상)', icon: Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 나이 선택
                _buildLabel('나이'),
                InkWell(
                  onTap: () => _selectAge(context),
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cake_outlined, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Text('$_selectedAge세', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 성별 선택
                _buildLabel('성별'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildGenderChip('남'),
                    const SizedBox(width: 16),
                    _buildGenderChip('여'),
                  ],
                ),
                const SizedBox(height: 32),

                // 회원가입 버튼
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                  onPressed: _submit,
                  child: const Text('회원가입 완료'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 입력 필드 위 레이블 위젯 생성 헬퍼
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColorDark,
        ),
      ),
    );
  }

  // InputDecoration 스타일 헬퍼
  InputDecoration _inputDecoration({required String hintText, IconData? icon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600]) : null,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    );
  }

  // 성별 선택 ChoiceChip 생성 헬퍼
  Widget _buildGenderChip(String label) {
    bool isSelected = _gender == label;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 15)),
      selected: isSelected,
      onSelected: (_) => setState(() => _gender = label),
      backgroundColor: Theme.of(context).chipTheme.backgroundColor ?? Colors.grey[200], // 테마 색상 활용
      selectedColor: Theme.of(context).chipTheme.selectedColor ?? Theme.of(context).primaryColor, // 테마 색상 활용
      elevation: 0,
      pressElevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: isSelected ? (Theme.of(context).chipTheme.selectedColor ?? Theme.of(context).primaryColor) : Colors.grey[300]!)
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }
}