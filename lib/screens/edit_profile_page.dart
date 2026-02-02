import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> initialUserData;

  const EditProfilePage({
    super.key,
    required this.user,
    required this.initialUserData,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>(); // 폼 상태 관리를 위한 키

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  String? _selectedGender;

  bool _isSaving = false; // 저장 중 로딩 상태


  final Color _sBlue = const Color(0xFF002D72);

  // 초기 성별 목록
  final List<String> _genders = ['남', '여', '기타', '선택 안함'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUserData['name'] as String? ?? '');
    _ageController = TextEditingController(text: widget.initialUserData['age']?.toString() ?? '');
    _selectedGender = widget.initialUserData['gender'] as String? ?? '선택 안함';
    if (!_genders.contains(_selectedGender)) {
      // 초기값이 목록에 없으면 '선택 안함'으로
      _selectedGender = '선택 안함';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return; // 유효성 검사 실패
    }
    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    try {
      String name = _nameController.text.trim();
      int? age;
      if (_ageController.text.trim().isNotEmpty) {
        age = int.tryParse(_ageController.text.trim());
        if (age == null || age <= 0 || age > 120) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유효한 나이를 입력해주세요 (1~120).')),
          );
          if (mounted) setState(() { _isSaving = false; });
          return;
        }
      }

      Map<String, dynamic> updatedData = {
        'name': name,
        'age': age, // null 허용
        'gender': (_selectedGender == '선택 안함' || _selectedGender == null) ? null : _selectedGender, // "선택 안함" 이면 null로 저장
      };
      // null 값 필드 제거 (Firestore에 null 필드 업데이트 방지)
      updatedData.removeWhere((key, value) => value == null && key != 'age' && key != 'gender');


      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다!')),
        );
        // 변경 성공 시 true를 반환하며 이전 페이지로 돌아감
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 업데이트 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 정보 수정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _sBlue,
        foregroundColor: Colors.white,
        elevation: 1.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: '저장',
            onPressed: _isSaving ? null : _saveProfile, // 저장 중이면 비활성화
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 이메일 (읽기 전용)
              TextFormField(
                initialValue: widget.user.email ?? '이메일 정보 없음',
                readOnly: true, // 이메일은 수정 불가
                decoration: InputDecoration(
                  labelText: '이메일 (수정 불가)',
                  icon: Icon(Icons.email_outlined, color: _sBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              // 이름 입력
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '이름',
                  icon: Icon(Icons.person_outline, color: _sBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),

              // 나이 입력
              TextFormField(
                controller: _ageController,
                decoration: InputDecoration(
                  labelText: '나이 (선택 사항)',
                  icon: Icon(Icons.cake_outlined, color: _sBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final age = int.tryParse(value.trim());
                    if (age == null || age <= 0 || age > 120) {
                      return '유효한 나이를 입력해주세요 (1~120).';
                    }
                  }
                  return null; // 비어있어도 유효 (선택 사항이므로)
                },
              ),
              const SizedBox(height: 20),

              // 성별 선택
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: '성별',
                  icon: Icon(Icons.wc_outlined, color: _sBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                items: _genders.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (mounted) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  }
                },
               validator: (value) {
                 if (value == null || value == '선택 안함') {
                   return '성별을 선택해주세요.';
                 }
                 return null;
               },
              ),
              const SizedBox(height: 30),

              // 저장 버튼
              ElevatedButton.icon(
                icon: _isSaving
                    ? Container(width: 20, height: 20, margin: const EdgeInsets.only(right: 8), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt_outlined, color: Colors.white),
                label: Text(_isSaving ? '저장 중...' : '변경사항 저장', style: const TextStyle(fontSize: 16, color: Colors.white)),
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}