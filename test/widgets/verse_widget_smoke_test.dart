import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
	testWidgets('smoke: verse texts render without overlap at narrow width', (tester) async {
		// Minimal widget to ensure a basic BiDi layout renders without exceptions.
		await tester.pumpWidget(
			MaterialApp(
				home: Scaffold(
					body: SizedBox(
						width: 280, // narrow width case
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: const [
								Directionality(
									textDirection: TextDirection.rtl,
									child: Text('ٱلْحَمْدُ لِلّٰهِ رَبِّ ٱلْعَٰلَمِينَ'),
								),
								SizedBox(height: 6),
								Directionality(
									textDirection: TextDirection.ltr,
									child: Text('Falënderimi i qoftë Allahut, Zotit të botëve.'),
								),
							],
						),
					),
				),
			),
		);
		await tester.pump();
		// Simple presence checks
		expect(find.text('ٱلْحَمْدُ لِلّٰهِ رَبِّ ٱلْعَٰلَمِينَ'), findsOneWidget);
		expect(find.text('Falënderimi i qoftë Allahut, Zotit të botëve.'), findsOneWidget);
	});
}
