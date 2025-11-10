import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isChangingPassword = false;
  bool _isLoading = false;
  
  // 알림 설정
  bool _notificationsEnabled = true;
  bool _notificationSound = true;
  bool _notificationVibration = true;
  // 다중 선택 가능한 알림 시간
  Set<String> _notificationTimings = {'1hour'}; // 3hours, 1hour, 15min, 10min

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notificationSound = prefs.getBool('notification_sound') ?? true;
      _notificationVibration = prefs.getBool('notification_vibration') ?? true;
      // 다중 선택 로드
      final timingsString = prefs.getStringList('notification_timings') ?? ['1hour'];
      _notificationTimings = timingsString.toSet();
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('notification_sound', _notificationSound);
    await prefs.setBool('notification_vibration', _notificationVibration);
    // 다중 선택 저장
    await prefs.setStringList('notification_timings', _notificationTimings.toList());
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('사용자가 로그인되어 있지 않습니다');

      // 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // 새 비밀번호로 변경
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('비밀번호가 변경되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 필드 초기화
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        setState(() => _isChangingPassword = false);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = '현재 비밀번호가 올바르지 않습니다';
          break;
        case 'weak-password':
          message = '새 비밀번호가 너무 약합니다 (최소 6자)';
          break;
        case 'requires-recent-login':
          message = '보안을 위해 다시 로그인해주세요';
          break;
        default:
          message = '비밀번호 변경 중 오류가 발생했습니다: ${e.message}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('비밀번호 재설정 이메일이 ${user.email}로 전송되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이메일 전송 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 계정 정보 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '계정 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('이메일'),
                    subtitle: Text(user?.email ?? '없음'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 비밀번호 변경 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '비밀번호 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!_isChangingPassword)
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('변경하기'),
                          onPressed: () {
                            setState(() => _isChangingPassword = true);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_isChangingPassword) ...[
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _currentPasswordController,
                            decoration: const InputDecoration(
                              labelText: '현재 비밀번호',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '현재 비밀번호를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _newPasswordController,
                            decoration: const InputDecoration(
                              labelText: '새 비밀번호',
                              prefixIcon: Icon(Icons.lock_open),
                              helperText: '최소 6자 이상',
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '새 비밀번호를 입력해주세요';
                              }
                              if (value.length < 6) {
                                return '비밀번호는 최소 6자 이상이어야 합니다';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(
                              labelText: '새 비밀번호 확인',
                              prefixIcon: Icon(Icons.lock_open),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '새 비밀번호를 다시 입력해주세요';
                              }
                              if (value != _newPasswordController.text) {
                                return '비밀번호가 일치하지 않습니다';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _isChangingPassword = false;
                                            _currentPasswordController.clear();
                                            _newPasswordController.clear();
                                            _confirmPasswordController.clear();
                                          });
                                        },
                                  child: const Text('취소'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _changePassword,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('변경'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      '비밀번호를 잊어버리셨나요?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.email),
                      label: const Text('비밀번호 재설정 이메일 받기'),
                      onPressed: _sendPasswordResetEmail,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 알림 설정 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '알림 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '즐겨찾기한 아이템의 마감일 알림',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 알림 켜기/끄기
                  SwitchListTile(
                    title: const Text('마감일 알림'),
                    subtitle: const Text('즐겨찾기한 아이템의 마감일이 다가오면 알려드립니다'),
                    value: _notificationsEnabled,
                    onChanged: (value) async {
                      setState(() => _notificationsEnabled = value);
                      await _saveNotificationSettings();
                      
                      if (value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('알림이 활성화되었습니다'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  if (_notificationsEnabled) ...[
                    const Divider(height: 24),
                    
                    // 알림 시간 선택 (다중 선택 가능)
                    Row(
                      children: [
                        const Text(
                          '알림 시간',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(다중 선택 가능)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    CheckboxListTile(
                      title: const Text('3시간 전'),
                      value: _notificationTimings.contains('3hours'),
                      onChanged: (value) async {
                        setState(() {
                          if (value == true) {
                            _notificationTimings.add('3hours');
                          } else {
                            _notificationTimings.remove('3hours');
                          }
                        });
                        await _saveNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('1시간 전'),
                      value: _notificationTimings.contains('1hour'),
                      onChanged: (value) async {
                        setState(() {
                          if (value == true) {
                            _notificationTimings.add('1hour');
                          } else {
                            _notificationTimings.remove('1hour');
                          }
                        });
                        await _saveNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('15분 전'),
                      value: _notificationTimings.contains('15min'),
                      onChanged: (value) async {
                        setState(() {
                          if (value == true) {
                            _notificationTimings.add('15min');
                          } else {
                            _notificationTimings.remove('15min');
                          }
                        });
                        await _saveNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('10분 전'),
                      value: _notificationTimings.contains('10min'),
                      onChanged: (value) async {
                        setState(() {
                          if (value == true) {
                            _notificationTimings.add('10min');
                          } else {
                            _notificationTimings.remove('10min');
                          }
                        });
                        await _saveNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const Divider(height: 24),
                    
                    // 소리/진동 설정
                    const Text(
                      '알림 방식',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    CheckboxListTile(
                      title: const Text('소리'),
                      value: _notificationSound,
                      onChanged: (value) async {
                        setState(() => _notificationSound = value ?? true);
                        await _saveNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('진동'),
                      value: _notificationVibration,
                      onChanged: (value) async {
                        setState(() => _notificationVibration = value ?? true);
                        await _saveNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 앱 정보 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '앱 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('버전'),
                    subtitle: const Text('1.0.0'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
