import 'package:family_finance/v3/phosphor_catalog.dart';
import 'package:family_finance/v3/screens/categories_manager_v3.dart';
import 'package:family_finance/v3/v3_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty search lists the curated icons first, then every icon', () {
    final all = CategoriesManagerV3.iconMatches('');
    expect(all.first, V3Design.categoryIconRegistry.keys.first);
    expect(all.toSet(), containsAll(phosphorCatalog.keys));
    expect(all.length, all.toSet().length);
  });

  test('search matches every word of the name', () {
    expect(CategoriesManagerV3.iconMatches('credit card'), contains('credit-card'));
    expect(CategoriesManagerV3.iconMatches('PILL'), contains('pill'));
    expect(CategoriesManagerV3.iconMatches('zzzz'), isEmpty);
  });

  test('stored names resolve from the full catalog', () {
    expect(V3Design.iconNamed('airplane'), phosphorCatalog['airplane']);
    expect(V3Design.iconNamed('nope'), isNull);
  });
}
