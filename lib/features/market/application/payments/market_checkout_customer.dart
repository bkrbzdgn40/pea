import 'package:flutter/foundation.dart';

@immutable
class MarketCheckoutCustomer {
  const MarketCheckoutCustomer({
    required this.email,
    required this.fullName,
    required this.phone,
    required this.address,
  });

  final String email;
  final String fullName;
  final String phone;
  final String address;

  MarketCheckoutCustomer normalized() {
    return MarketCheckoutCustomer(
      email: email.trim(),
      fullName: fullName.trim(),
      phone: phone.trim(),
      address: address.trim(),
    );
  }

  Map<String, Object> toJson() {
    final value = normalized();
    return <String, Object>{
      'email': value.email,
      'fullName': value.fullName,
      'phone': value.phone,
      'address': value.address,
    };
  }

  String get fingerprint {
    final value = normalized();
    return '${value.email}\u0000${value.fullName}\u0000'
        '${value.phone}\u0000${value.address}';
  }
}
