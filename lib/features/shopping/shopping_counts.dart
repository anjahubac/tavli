/// Brojevi sa padežima za Nabavku.
library;

import '../../domain/recipe_format.dart';

/// "1 sastojak", "2 sastojka", "5 sastojaka" (11–14 su "sastojaka").
String ingredientsCount(int n) =>
    countLabel(n, 'sastojak', 'sastojka', 'sastojaka');

/// "1 stavka", "2 stavke", "5 stavki" (11–14 su "stavki").
String itemsCount(int n) => countLabel(n, 'stavka', 'stavke', 'stavki');
