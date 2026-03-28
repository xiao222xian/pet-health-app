import 'package:flutter/cupertino.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/api_service.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../app/theme.dart';

class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key});

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  final _symptomsController = TextEditingController();
  bool _disclaimerAccepted = false;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;
  String? _petId;

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _loadPet() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    final pets = await SupabaseService.client
        .from('pets')
        .select('id')
        .eq('user_id', userId)
        .limit(1);
    if ((pets as List).isNotEmpty) {
      setState(() { _petId = pets[0]['id'] as String; });
    }
  }

  Future<void> _consult() async {
    if (_symptomsController.text.trim().length < 5) return;
    if (_petId == null) return;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await ApiService.post('/consult', {
        'pet_id': _petId,
        'symptoms': _symptomsController.text.trim(),
      });
      setState(() { _result = result; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = '请求失败，请检查网络连接'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Color _colorForRisk(String? risk) {
    switch (risk) {
      case 'emergency':
        return AppTheme.dangerColor;
      case 'high':
        return const Color(0xFFFF8C42);
      case 'medium':
        return AppTheme.warningColor;
      default:
        return AppTheme.secondaryColor;
    }
  }

  String _labelForRisk(String? risk) {
    switch (risk) {
      case 'emergency':
        return '紧急 — 立即就医';
      case 'high':
        return '严重 — 尽快就医';
      case 'medium':
        return '中等 — 建议就医';
      default:
        return '轻微 — 可观察';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _loading,
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('AI 问诊')),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_disclaimerAccepted)
                _buildDisclaimer()
              else ...[
                const Text(
                  '描述症状',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _symptomsController,
                  placeholder: '请详细描述宠物的症状，例如：精神不振、食欲下降、持续咳嗽3天...',
                  maxLines: 5,
                  padding: const EdgeInsets.all(14),
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: _consult,
                  child: const Text('开始问诊'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.dangerColor),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _buildResult(_result!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: AppTheme.warningColor,
              ),
              SizedBox(width: 8),
              Text(
                '使用须知',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '本功能由 AI 提供辅助参考，仅用于初步了解宠物症状。\n\n'
            '• 不构成任何兽医诊断意见\n'
            '• 不能替代专业兽医检查\n'
            '• 紧急情况请立即前往宠物医院\n\n'
            '请在理解以上须知后继续使用。',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: () => setState(() { _disclaimerAccepted = true; }),
            child: const Text('我已了解，继续使用'),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> result) {
    final riskLevel = result['risk_level'] as String?;
    final riskColor = _colorForRisk(riskLevel);
    final advice = result['advice'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: riskColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: riskColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _labelForRisk(riskLevel),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(result['summary'] as String? ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '建议',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...advice.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
                Expanded(child: Text(item.toString())),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            result['disclaimer'] as String? ??
                '本结果仅供参考，不构成兽医诊断意见。如有紧急情况请立即就医。',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
