import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/item_model.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/metadata_service.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _sizeController = TextEditingController();
  final _memoController = TextEditingController();
  final _priceController = TextEditingController();
  final _commentController = TextEditingController();
  final _uuid = const Uuid();

  String _thumbnailUrl = '';
  DateTime? _deadline;
  bool _isLoading = false;
  bool _isPurchased = false;
  bool _isPublic = false;
  String? _selectedShippingGroup;
  final List<String> _tags = [];

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _sizeController.dispose();
    _memoController.dispose();
    _priceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetadata() async {
    if (_urlController.text.isEmpty) {
      _showSnackBar('URL을 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final metadata = await MetadataService.fetchMetadata(_urlController.text);
      setState(() {
        _titleController.text = metadata['title'] ?? '제목 없음';
        _thumbnailUrl = metadata['image'] ?? '';
      });
      _showSnackBar('정보를 불러왔습니다');
    } catch (e) {
      _showSnackBar('정보를 불러오는데 실패했습니다');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      // 시간 입력 다이얼로그 (타이핑 방식)
      final hourController = TextEditingController(text: '14');
      final minuteController = TextEditingController(text: '00');
      
      final result = await showDialog<Map<String, int>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('마감 시간 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hourController,
                      decoration: const InputDecoration(
                        labelText: '시',
                        hintText: '14',
                        suffixText: '시',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: minuteController,
                      decoration: const InputDecoration(
                        labelText: '분',
                        hintText: '00',
                        suffixText: '분',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '24시간 형식으로 입력해주세요 (예: 14:30)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final hour = int.tryParse(hourController.text) ?? 14;
                final minute = int.tryParse(minuteController.text) ?? 0;
                
                if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
                  Navigator.pop(context, {'hour': hour, 'minute': minute});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('올바른 시간을 입력해주세요')),
                  );
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );

      if (result != null) {
        setState(() {
          _deadline = DateTime(
            date.year,
            date.month,
            date.day,
            result['hour']!,
            result['minute']!,
          );
        });
      }
    }
  }

  void _setQuickDeadline(int days) {
    setState(() {
      _deadline = MetadataService.getQuickDeadline(days);
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_deadline == null) {
        _showSnackBar('마감일을 설정해주세요');
        return;
      }

      final userProvider = context.read<UserProvider>();
      final itemProvider = context.read<ItemProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) return;

      final item = ItemModel(
        id: _uuid.v4(),
        userId: currentUser.uid,
        url: _urlController.text,
        title: _titleController.text,
        thumbnailUrl: _thumbnailUrl,
        deadline: _deadline!,
        size: _sizeController.text.isEmpty ? null : _sizeController.text,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        isPurchased: _isPurchased,
        purchasePrice: _priceController.text.isEmpty
            ? null
            : int.tryParse(_priceController.text.replaceAll(',', '')),
        shippingGroupId: _selectedShippingGroup,
        isPublic: _isPublic,
        tags: _tags,
        curatorComment: _commentController.text.isEmpty
            ? null
            : _commentController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await itemProvider.addItem(item);

      // 합배송 그룹 업데이트
      if (_selectedShippingGroup != null) {
        await itemProvider.updateShippingGroup(_selectedShippingGroup!);
      }

      if (mounted) {
        _showSnackBar('아이템이 추가되었습니다');
        _resetForm();
      }
    }
  }

  void _resetForm() {
    _urlController.clear();
    _titleController.clear();
    _sizeController.clear();
    _memoController.clear();
    _priceController.clear();
    _commentController.clear();
    setState(() {
      _thumbnailUrl = '';
      _deadline = null;
      _isPurchased = false;
      _isPublic = false;
      _selectedShippingGroup = null;
      _tags.clear();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('아이템 추가'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL 입력
              const Text(
                'STEP 1: 옥션 링크 입력',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // 웹 브라우저 제한 안내
              if (kIsWeb) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '웹 브라우저에서는 링크 자동 불러오기가 제한됩니다.\nAndroid 앱에서는 정상 작동합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: '옥션 링크',
                        hintText: 'https://...',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'URL을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _fetchMetadata,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('불러오기'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 썸네일 미리보기
              if (_thumbnailUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _thumbnailUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 제목
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 마감일 설정
              const Text(
                'STEP 2: 마감일 설정',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 빠른 선택
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('+1일'),
                    onPressed: () => _setQuickDeadline(1),
                  ),
                  ActionChip(
                    label: const Text('+3일'),
                    onPressed: () => _setQuickDeadline(3),
                  ),
                  ActionChip(
                    label: const Text('+7일'),
                    onPressed: () => _setQuickDeadline(7),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 날짜 선택
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_deadline == null
                    ? '직접 입력'
                    : DateFormat('yyyy.MM.dd HH:mm').format(_deadline!)),
                onPressed: _selectDate,
              ),
              const SizedBox(height: 24),

              // 선택 입력
              const Text(
                'STEP 3: 추가 정보 (선택)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(
                  labelText: '사이즈',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '메모',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // 공개 설정
              const Divider(height: 32),
              CheckboxListTile(
                title: const Text('공개 (피드에 공유)'),
                subtitle: const Text('다른 사용자들이 볼 수 있습니다'),
                value: _isPublic,
                onChanged: (value) {
                  setState(() => _isPublic = value ?? false);
                },
                contentPadding: EdgeInsets.zero,
              ),

              if (_isPublic) ...[
                TextFormField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: '추천 코멘트',
                    hintText: '이 아이템을 추천하는 이유를 적어주세요',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
