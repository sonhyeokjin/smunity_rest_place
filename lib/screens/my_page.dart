import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

class MyPage extends StatefulWidget {
  final User user; // 현재 로그인 된 사용자 정보

  const MyPage({super.key, required this.user});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  Map<String, dynamic>? _userData; // Firestore에서 가져온 사용자 데이터를 저장할 변수
  bool _isLoading = true; // 데이터 로딩 상태

  // 앱 테마 색상
  final Color _sBlue = const Color(0xFF002D72);
  final Color _scaffoldBgColor = const Color(0xFFF0F4FA);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      if (mounted) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보를 불러오는데 실패했습니다: $e')),
        );
      }
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말로 로그아웃 하시겠습니까?'),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소', style: TextStyle(color: _sBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // 로그인 페이지로 이동하면서 이전의 모든 페이지 스택 제거
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false,
      );
    }
  }

  Widget _buildInfoTile(IconData icon, String title, String? value) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: Icon(icon, color: _sBlue, size: 26),
        title: Text(
          title,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]), // 대괄호 사용
        ),
        subtitle: Text(
          value ?? '정보 없음',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _sBlue,
        foregroundColor: Colors.white,
        elevation: 1.0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _sBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 사용자 프로필 정보 섹션
            if (_userData != null) ...[
              _buildInfoTile(Icons.person_outline, '이름', _userData!['name'] as String?),
              _buildInfoTile(Icons.email_outlined, '이메일', widget.user.email), // Firebase Auth에서 가져온 이메일
              _buildInfoTile(Icons.cake_outlined, '나이', _userData!['age']?.toString()),
              _buildInfoTile(
                _userData!['gender'] == '남' ? Icons.male_outlined : Icons.female_outlined,
                '성별',
                _userData!['gender'] as String?,
              ),
            ] else if (!_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('사용자 정보를 찾을 수 없습니다.', style: TextStyle(fontSize: 16)),
                ),
              )
            ],

            const SizedBox(height: 30),

            // 로그아웃 버튼
            ElevatedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('로그아웃', style: TextStyle(fontSize: 16, color: Colors.white)),
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                elevation: 2.0,
              ),
            ),
            const SizedBox(height: 20),

            // 회원 정보 수정 버튼
            OutlinedButton.icon(
              icon: Icon(Icons.edit_outlined, color: _sBlue),
              label: Text('회원 정보 수정', style: TextStyle(color: _sBlue)),
              onPressed: () async {
                if (_userData != null) {
                  final bool? profileWasUpdated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(
                        user: widget.user,
                        initialUserData: _userData!, // 현재 사용자 데이터 전달
                      ),
                    ),
                  );
                  if (profileWasUpdated == true && mounted) {
                    _fetchUserData(); // 사용자 데이터 다시 불러오기
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('사용자 정보를 먼저 불러와주세요.')),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _sBlue.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}