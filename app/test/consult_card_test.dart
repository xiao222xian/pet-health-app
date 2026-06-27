import 'package:app/features/consult/consult_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => CupertinoApp(
      home: CupertinoPageScaffold(
        child: SafeArea(
          child: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders guide response and taps follow-up question',
      (tester) async {
    String? selected;
    await tester.pumpWidget(_wrap(ConsultStructuredCard(
      response: const {
        'response_type': 'guide',
        'risk_level': 'unknown',
        'title': '先补充症状信息',
        'short_answer': '用户只是寒暄，没有症状信息。',
        'missing_info': ['具体症状'],
        'follow_up_questions': [
          {'text': '请描述宠物哪里不舒服。'}
        ],
        'next_actions': [],
      },
      onPromptSelected: (value) => selected = value,
    )));

    expect(find.text('先补充症状信息'), findsOneWidget);
    expect(find.text('请描述宠物哪里不舒服。'), findsOneWidget);

    await tester.tap(find.text('请描述宠物哪里不舒服。'));
    expect(selected, '请描述宠物哪里不舒服。');
  });

  testWidgets('renders emergency response', (tester) async {
    await tester.pumpWidget(_wrap(const ConsultStructuredCard(
      response: {
        'response_type': 'emergency_alert',
        'risk_level': 'emergency',
        'title': '疑似中毒或误食风险',
        'short_answer': '建议立即联系宠物医院。',
        'emergency': {
          'immediate_actions': ['立即联系附近宠物医院'],
          'avoid': ['不要自行催吐'],
        },
        'next_actions': [],
      },
    )));

    expect(find.text('疑似中毒或误食风险'), findsOneWidget);
    expect(find.text('立刻处理'), findsOneWidget);
    expect(find.text('不要这样做'), findsOneWidget);
  });

  testWidgets('renders triage response sections', (tester) async {
    await tester.pumpWidget(_wrap(const ConsultStructuredCard(
      response: {
        'response_type': 'triage_report',
        'risk_level': 'medium',
        'summary': '需要重点观察。',
        'possible_causes': ['饮食刺激'],
        'home_care': ['少量多次饮水'],
        'watch_points': ['精神食欲'],
        'when_to_seek_vet': ['持续呕吐'],
      },
    )));

    expect(find.text('可能原因'), findsOneWidget);
    expect(find.text('居家护理'), findsOneWidget);
    expect(find.text('接下来观察什么'), findsOneWidget);
    expect(find.text('这些情况建议就医'), findsOneWidget);
  });
}
