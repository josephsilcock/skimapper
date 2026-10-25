import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/text/fold.dart';

void main() {
  test('folds away accents and capitals', () {
    expect(folded('Évolène'), 'evolene');
    expect(folded('Les 3 Vallées'), 'les 3 vallees');
  });
}
