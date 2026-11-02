import 'package:flutter_test/flutter_test.dart';
import 'package:topo_survey/main.dart';

void main() {
  testWidgets('TopoSurveyApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TopoSurveyApp());
    expect(find.text('TopoSurvey 3D'), findsOneWidget);
  });
}
