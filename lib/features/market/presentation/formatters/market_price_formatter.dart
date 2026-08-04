import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';

class MarketPriceFormatter {
  MarketPriceFormatter(Locale locale) : _locale = locale;

  final Locale _locale;

  String format(Money money) {
    final decimalDigits = money.minorUnits % 100 == 0 ? 0 : 2;
    final symbol = money.currencyCode == 'TRY' ? '₺' : '${money.currencyCode} ';
    return NumberFormat.currency(
      locale: _locale.toLanguageTag(),
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(money.majorUnits);
  }
}
