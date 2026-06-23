import 'dart:collection';

class MovingAverageFilter {
  final int windowSize;
  final Queue<double> _values = Queue<double>();
  double _sum = 0.0;

  /// [windowSize] değeri filtrenin ne kadar geriye bakacağını belirler.
  /// İdeal FPS için genellikle 5 ile 10 arası bir değer tercih edilir.
  MovingAverageFilter({this.windowSize = 5});

  /// Yeni bir açı değeri ekler ve filtrelenmiş (pürüzsüz) ortalamayı döndürür.
  double process(double newValue) {
    _values.addLast(newValue);
    _sum += newValue;

    // Kuyruk kapasitesi dolduğunda en eski veriyi at ve toplamdan çıkar
    if (_values.length > windowSize) {
      double oldestValue = _values.removeFirst();
      _sum -= oldestValue;
    }

    // Mevcut değerlerin ortalamasını döndür
    return _sum / _values.length;
  }

  /// Yeni bir antrenman setine geçildiğinde kuyruğu sıfırlamak için kullanılır
  void reset() {
    _values.clear();
    _sum = 0.0;
  }
}
