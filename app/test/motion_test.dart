import 'package:astrbot_manager/l10n.dart';
import 'package:astrbot_manager/screens/connection_screen.dart';
import 'package:astrbot_manager/state/app_state.dart';
import 'package:astrbot_manager/widgets/glass.dart';
import 'package:astrbot_manager/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder pressTransition() => find
    .descendant(
      of: find.byType(MotionPress).first,
      matching: find.byType(ScaleTransition),
    )
    .first;

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('rapid tab changes preserve input, scroll and mounted pages', (
    tester,
  ) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(host(ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (context, value, child) => MotionIndexedStack(
        index: value,
        children: const [
          _ProbePage(key: ValueKey('a')),
          _ProbePage(key: ValueKey('b'))
        ],
      ),
    )));
    final first =
        tester.state<_ProbePageState>(find.byKey(const ValueKey('a')));
    await tester.enterText(find.byType(TextField).first, 'keep my input');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    first.scroll.jumpTo(180);
    await tester.pump();
    expect(first.scroll.offset, 180);
    index.value = 1;
    await tester.pump();
    expect(TickerMode.of(first.context), isFalse);
    for (final value in [0, 1, 0, 1, 0]) {
      index.value = value;
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
    expect(tester.state(find.byKey(const ValueKey('a'))), same(first));
    expect(first.scroll.offset, 180);
    expect(first.input.text, 'keep my input');
    expect(TickerMode.of(first.context), isTrue);
    expect(find.byType(_ProbePage, skipOffstage: false), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows delayed content and new tabs immediately', (
    tester,
  ) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(host(
        ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (context, value, child) => MotionIndexedStack(
            index: value,
            children: const [
              MotionEntrance(order: 5, child: Text('first')),
              Text('second'),
            ],
          ),
        ),
        reduced: true));
    expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1);
    index.value = 1;
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
    expect(tester.getTopLeft(find.text('second')).dx, 0);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
      'tab slide keeps both pages visible and retargets without jumping',
      (tester) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(host(ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (context, value, _) =>
          MotionIndexedStack(index: value, children: const [
        ColoredBox(key: ValueKey('left'), color: Colors.red),
        ColoredBox(key: ValueKey('right'), color: Colors.blue)
      ]),
    )));
    index.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final left = tester.getTopLeft(find.byKey(const ValueKey('left'))).dx;
    final right = tester.getTopLeft(find.byKey(const ValueKey('right'))).dx;
    expect(left, lessThan(0));
    expect(right, greaterThan(0));
    expect(right - left, closeTo(800, 0.01));
    index.value = 0;
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('left'))).dx,
        closeTo(left, 0.01));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('left'))).dx, 0);
  });

  testWidgets('native-view page slides with its neighbour without compositing',
      (tester) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(host(ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (context, value, _) => MotionIndexedStack(
          index: value,
          nativeViewPages: const {
            1
          },
          children: const [
            Text('normal'),
            SizedBox(key: ValueKey('native-view'))
          ]),
    )));
    index.value = 1;
    await tester.pump();
    final native = find.byKey(const ValueKey('native-view'));
    expect(find.ancestor(of: native, matching: find.byType(Transform)),
        findsNothing);
    expect(find.ancestor(of: native, matching: find.byType(Opacity)),
        findsNothing);
    final width = tester.getSize(find.byType(MotionIndexedStack)).width;
    expect(tester.getTopLeft(native).dx, closeTo(width, 0.01));
    await tester.pump(const Duration(milliseconds: 120));
    final normalOffset = tester.getTopLeft(find.text('normal')).dx;
    final nativeOffset = tester.getTopLeft(native).dx;
    expect(normalOffset, lessThan(0));
    expect(nativeOffset, inExclusiveRange(0, width));
    expect(nativeOffset - normalOffset, closeTo(width, 0.01));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(native).dx, 0);
    index.value = 0;
    await tester.pump();
    expect(find.text('normal'), findsOneWidget);
    expect(tester.getTopLeft(find.text('normal')).dx, closeTo(-width, 0.01));
    await tester.pump(const Duration(milliseconds: 120));
    final returningOffset = tester.getTopLeft(find.text('normal')).dx;
    final outgoingOffset = tester.getTopLeft(native).dx;
    expect(returningOffset, inExclusiveRange(-width, 0));
    expect(outgoingOffset, inExclusiveRange(0, width));
    expect(outgoingOffset - returningOffset, closeTo(width, 0.01));
    expect(find.ancestor(of: native, matching: find.byType(Transform)),
        findsNothing);
    expect(find.ancestor(of: native, matching: find.byType(Opacity)),
        findsNothing);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('entrance completes once and can be removed mid animation', (
    tester,
  ) async {
    await tester.pumpWidget(host(const MotionEntrance(child: Text('initial'))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(const MotionEntrance(child: Text('updated'))));
    expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1);
    await tester.pumpWidget(host(const SizedBox()));
    await tester
        .pumpWidget(host(const MotionEntrance(order: 5, child: Text('new'))));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled presses release without triggering an action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(host(Center(
        child: FrostedButton(
      label: 'Restart',
      onPressed: () => calls++,
    ))));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Restart')));
    await tester.pumpAndSettle();
    expect(tester.widget<ScaleTransition>(pressTransition()).scale.value,
        lessThan(1));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.widget<ScaleTransition>(pressTransition()).scale.value, 1);
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  for (var from = 0; from < 4; from++) {
    for (var to = 0; to < 4; to++) {
      if (from == to) continue;
      testWidgets(
          'tab $from to $to keeps page direction, speed and spacing consistent',
          (tester) async {
        final index = ValueNotifier(from);
        addTearDown(index.dispose);
        await tester.pumpWidget(host(ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (context, value, _) => MotionIndexedStack(
            index: value,
            nativeViewPages: const {2},
            children: [
              for (var i = 0; i < 4; i++)
                SizedBox.expand(
                    key: ValueKey('page-$i'), child: Text('Page $i')),
            ],
          ),
        )));
        await tester.pumpAndSettle();
        index.value = to;
        await tester.pump();
        final outgoing = find.byKey(ValueKey('page-$from'));
        final incoming = find.byKey(ValueKey('page-$to'));
        final width = tester.getSize(find.byType(MotionIndexedStack)).width;
        final direction = to > from ? 1.0 : -1.0;
        final outgoingStart = tester.getTopLeft(outgoing).dx;
        final incomingStart = tester.getTopLeft(incoming).dx;
        expect(outgoingStart, closeTo(0, 0.01));
        expect(incomingStart, closeTo(direction * width, 0.01));
        await tester.pump(const Duration(milliseconds: 120));
        final outgoingOffset = tester.getTopLeft(outgoing).dx;
        final incomingOffset = tester.getTopLeft(incoming).dx;
        expect(outgoingOffset * direction, inExclusiveRange(-width, 0));
        expect(incomingOffset * direction, inExclusiveRange(0, width));
        expect(
            incomingOffset - outgoingOffset, closeTo(direction * width, 0.01));
        expect(incomingOffset - incomingStart,
            closeTo(outgoingOffset - outgoingStart, 0.01));
        if (from == 2 || to == 2) {
          final native = find.byKey(const ValueKey('page-2'));
          expect(find.ancestor(of: native, matching: find.byType(Transform)),
              findsNothing);
          expect(find.ancestor(of: native, matching: find.byType(Opacity)),
              findsNothing);
        }
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(ValueKey('page-$to'))).dx, 0);
        expect(find.byKey(ValueKey('page-$from')), findsNothing);
      });
    }
  }

  testWidgets('rapid retargeting through WebUI preserves every visible offset',
      (tester) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(host(ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (context, value, _) => MotionIndexedStack(
        index: value,
        nativeViewPages: const {2},
        children: [
          for (var i = 0; i < 4; i++)
            SizedBox.expand(key: ValueKey('rapid-page-$i')),
        ],
      ),
    )));
    index.value = 2;
    await tester.pump();
    for (final next in [1, 3, 2, 0]) {
      await tester.pump(const Duration(milliseconds: 70));
      final offsets = <int, double>{};
      for (var i = 0; i < 4; i++) {
        final page = find.byKey(ValueKey('rapid-page-$i'));
        if (page.evaluate().isNotEmpty) {
          offsets[i] = tester.getTopLeft(page).dx;
        }
      }
      index.value = next;
      await tester.pump();
      for (final entry in offsets.entries) {
        expect(
            tester
                .getTopLeft(find.byKey(ValueKey('rapid-page-${entry.key}')))
                .dx,
            closeTo(entry.value, 0.01));
      }
      final native = find.byKey(const ValueKey('rapid-page-2'));
      expect(find.ancestor(of: native, matching: find.byType(Transform)),
          findsNothing);
      expect(find.ancestor(of: native, matching: find.byType(Opacity)),
          findsNothing);
    }
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('rapid-page-0'))).dx, 0);
    for (var i = 1; i < 4; i++) {
      expect(find.byKey(ValueKey('rapid-page-$i')), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quick tap completes a visible press pulse exactly once',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(Center(
        child: FrostedButton(
      label: 'Quick tap',
      onPressed: () => calls++,
    ))));
    await tester.tap(find.text('Quick tap'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<ScaleTransition>(pressTransition()).scale.value,
        lessThan(0.96));
    expect(calls, 1);
    await tester.pumpAndSettle();
    expect(tester.widget<ScaleTransition>(pressTransition()).scale.value, 1);
  });

  testWidgets(
      'quick icon and chip taps have feedback and respect reduced motion',
      (tester) async {
    var calls = 0;
    for (final reduced in [false, true]) {
      await tester.pumpWidget(host(
          Center(
              child: MotionIconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => calls++,
          )),
          reduced: reduced));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final scale =
          tester.widget<ScaleTransition>(pressTransition()).scale.value;
      expect(scale, reduced ? equals(1) : lessThan(0.96));
      await tester.pumpAndSettle();
    }
    expect(calls, 2);
    await tester.pumpWidget(host(Center(
        child: MotionTap(
      onTap: () => calls++,
      child: const Text('chip'),
    ))));
    await tester.tap(find.text('chip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<ScaleTransition>(pressTransition()).scale.value,
        lessThan(0.96));
    expect(calls, 3);
    await tester.pumpAndSettle();
  });

  testWidgets('disposing a quick-tap pulse never calls a disposed controller',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(Center(
        child: MotionTap(
      onTap: () => calls++,
      child: const Text('close'),
    ))));
    await tester.tap(find.text('close'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and disabled buttons never trigger their action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(host(Center(
        child: FrostedButton(
      label: 'Busy',
      loading: true,
      onPressed: () => calls++,
    ))));
    await tester.tap(find.text('Busy'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 0);
    await tester
        .pumpWidget(host(Center(child: FrostedButton(label: 'Disabled'))));
    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow action buttons fit while loading content changes',
      (tester) async {
    for (final loading in [false, true, false]) {
      await tester.pumpWidget(host(Center(
          child: SizedBox(
        width: 105,
        child: FrostedButton(
            label: 'WebUI',
            icon: Icons.language,
            loading: loading,
            onPressed: () {}),
      ))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('switching authentication keeps entered credentials',
      (tester) async {
    L10n.lang = 'zh';
    final app = AppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: host(ConnectionScreen()),
    ));
    await tester.pumpAndSettle();
    Finder field(String hint) => find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == hint,
        );
    await tester.enterText(field('密码'), 'example password');
    await tester.tap(find.text('私钥登录'));
    await tester.pumpAndSettle();
    await tester.enterText(field('私钥 PEM 文本'), 'example private key');
    await tester.tap(find.text('阿里云登录'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('密码')).controller!.text,
        'example password');
    await tester.tap(find.text('私钥登录'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('私钥 PEM 文本')).controller!.text,
        'example private key');
    expect(tester.takeException(), isNull);
  });
}

class _ProbePage extends StatefulWidget {
  const _ProbePage({super.key});

  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  final input = TextEditingController();
  final scroll = ScrollController();

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        controller: scroll,
        children: [
          TextField(controller: input),
          for (var i = 0; i < 40; i++)
            SizedBox(height: 48, child: Text('Row $i')),
        ],
      );
}
