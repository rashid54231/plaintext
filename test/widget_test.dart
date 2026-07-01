import 'package:flutter_test/flutter_test.dart';
import 'package:plaintext/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskFlowApp());
    expect(find.byType(TaskFlowApp), findsOneWidget);
  });
}
