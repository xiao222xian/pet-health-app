import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/pet.dart';
import '../../shared/widgets/loading_overlay.dart';

class PetFormScreen extends StatefulWidget {
  final String? petId;
  const PetFormScreen({super.key, this.petId});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  String _species = 'dog';
  String _gender = 'male';
  bool _neutered = false;
  DateTime? _birthDate;
  bool _saving = false;
  Pet? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.petId != null) _loadExisting();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final data = await SupabaseService.client
        .from('pets')
        .select()
        .eq('id', widget.petId!)
        .single();
    final pet = Pet.fromJson(data);
    setState(() {
      _existing = pet;
      _nameController.text = pet.name;
      _breedController.text = pet.breed ?? '';
      _weightController.text = pet.weightKg?.toString() ?? '';
      _species = pet.species;
      _gender = pet.gender ?? 'male';
      _neutered = pet.neutered;
      _birthDate = pet.birthDate;
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() { _saving = true; });

    final userId = SupabaseService.userId!;
    final payload = <String, dynamic>{
      'user_id': userId,
      'name': _nameController.text.trim(),
      'species': _species,
      'gender': _gender,
      'neutered': _neutered,
    };
    if (_breedController.text.trim().isNotEmpty) {
      payload['breed'] = _breedController.text.trim();
    }
    if (_weightController.text.isNotEmpty) {
      payload['weight_kg'] = double.tryParse(_weightController.text);
    }
    if (_birthDate != null) {
      payload['birth_date'] = _birthDate!.toIso8601String().substring(0, 10);
    }

    try {
      if (_existing != null) {
        await SupabaseService.client
            .from('pets')
            .update(payload)
            .eq('id', _existing!.id);
      } else {
        await SupabaseService.client.from('pets').insert(payload);
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _saving,
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.petId == null ? '添加宠物' : '编辑档案'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _label('名字'),
              CupertinoTextField(
                controller: _nameController,
                placeholder: '宠物的名字',
                padding: const EdgeInsets.all(14),
              ),
              const SizedBox(height: 16),
              _label('物种'),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _species,
                onValueChanged: (v) => setState(() { _species = v!; }),
                children: const {
                  'dog': Text('狗'),
                  'cat': Text('猫'),
                  'other': Text('其他'),
                },
              ),
              const SizedBox(height: 16),
              _label('品种（可选）'),
              CupertinoTextField(
                controller: _breedController,
                placeholder: '例：金毛寻回犬',
                padding: const EdgeInsets.all(14),
              ),
              const SizedBox(height: 16),
              _label('性别'),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _gender,
                onValueChanged: (v) => setState(() { _gender = v!; }),
                children: const {
                  'male': Text('雄'),
                  'female': Text('雌'),
                  'unknown': Text('未知'),
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('已绝育'),
                  CupertinoSwitch(
                    value: _neutered,
                    onChanged: (v) => setState(() { _neutered = v; }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _label('体重 (kg)'),
              CupertinoTextField(
                controller: _weightController,
                placeholder: '例：8.5',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                padding: const EdgeInsets.all(14),
              ),
              const SizedBox(height: 16),
              _label('出生日期'),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => SizedBox(
                    height: 250,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      maximumDate: DateTime.now(),
                      initialDateTime: _birthDate ??
                          DateTime.now().subtract(const Duration(days: 365)),
                      onDateTimeChanged: (d) => setState(() { _birthDate = d; }),
                    ),
                  ),
                ),
                child: Text(
                  _birthDate == null
                      ? '选择日期'
                      : '${_birthDate!.year}年${_birthDate!.month}月${_birthDate!.day}日',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
    ),
  );
}
