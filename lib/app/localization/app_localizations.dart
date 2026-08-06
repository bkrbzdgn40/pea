import 'package:flutter/widgets.dart';

/// Application copy for every locale currently exposed in Settings.
///
/// The project intentionally keeps localization deterministic and local. There
/// is no remote translation layer and no generated runtime dependency. Feature
/// screens consume this class from [BuildContext], while non-widget code can
/// construct it from the active locale when localized copy is required.
class AppLocalizations {
  const AppLocalizations(this.locale);

  static const supportedLocales = <Locale>[Locale('tr'), Locale('en')];

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(Localizations.localeOf(context));
  }

  final Locale locale;

  bool get isTurkish => locale.languageCode.toLowerCase() == 'tr';

  String pick({required String tr, required String en}) => isTurkish ? tr : en;

  // Global / shell
  String get appName => 'Pose Analysis';
  String get workoutAnalysis =>
      pick(tr: 'Antrenman Analizi', en: 'Workout Analysis');
  String get settings => pick(tr: 'Ayarlar', en: 'Settings');
  String get language => pick(tr: 'Dil', en: 'Language');
  String get appLanguage => pick(tr: 'Uygulama dili', en: 'App language');
  String get turkish => pick(tr: 'Türkçe', en: 'Turkish');
  String get english => pick(tr: 'İngilizce', en: 'English');
  String get camera => pick(tr: 'Kamera', en: 'Camera');
  String get cameraPreference =>
      pick(tr: 'Kamera tercihi', en: 'Camera preference');
  String get frontCamera => pick(tr: 'Ön kamera', en: 'Front camera');
  String get backCamera => pick(tr: 'Arka kamera', en: 'Back camera');
  String get imageQuality => pick(tr: 'Görüntü kalitesi', en: 'Image quality');
  String get low => pick(tr: 'Düşük', en: 'Low');
  String get medium => pick(tr: 'Orta', en: 'Medium');
  String get high => pick(tr: 'Yüksek', en: 'High');
  String get liveFeedback =>
      pick(tr: 'Canlı geri bildirim', en: 'Live feedback');
  String get voiceCoach => pick(tr: 'Sesli koç', en: 'Voice coach');
  String get voiceCoachDescription => pick(
    tr: 'Anlık form yönergelerini sesli olarak iletir.',
    en: 'Speaks live form guidance during analysis.',
  );
  String get feedbackFrequency =>
      pick(tr: 'Geri bildirim sıklığı', en: 'Feedback frequency');
  String get feedbackFrequencyDescription => pick(
    tr: 'Aynı sesli uyarının ne kadar sık tekrarlanacağını belirler.',
    en: 'Controls how often the same voice cue may repeat.',
  );
  String get feedbackFrequencyReduced => pick(tr: 'Az', en: 'Reduced');
  String get feedbackFrequencyNormal => pick(tr: 'Normal', en: 'Normal');
  String get feedbackFrequencyFrequent => pick(tr: 'Sık', en: 'Frequent');
  String get privacyAndData =>
      pick(tr: 'Gizlilik ve Verilerim', en: 'Privacy and My Data');
  String get savedWorkoutDataExplanation => pick(
    tr: 'Kamera görüntüleri saklanmaz. Tekrar, süre, skor ve teknik ölçümler antrenman geçmişin için bulutta tutulur.',
    en: 'Camera images are not stored. Reps, duration, scores, and technical measurements are kept in the cloud for your workout history.',
  );
  String get deleteAllHistory =>
      pick(tr: 'Tüm Geçmişi Sil', en: 'Delete All History');
  String get deleteAllHistoryDescription => pick(
    tr: 'Kaydedilmiş tüm antrenmanları ve tekrar detaylarını kaldırır.',
    en: 'Removes every saved workout and its repetition details.',
  );
  String get deleteAllHistoryTitle =>
      pick(tr: 'Tüm geçmiş silinsin mi?', en: 'Delete all history?');
  String get deleteAllHistoryMessage => pick(
    tr: 'Bütün antrenman oturumların ve tekrar detayların kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    en: 'All workout sessions and repetition details will be permanently deleted. This action cannot be undone.',
  );
  String get allHistoryDeleted => pick(
    tr: 'Tüm antrenman geçmişi silindi.',
    en: 'All workout history was deleted.',
  );
  String get allHistoryDeleteFailed => pick(
    tr: 'Tüm geçmiş silinemedi. Bazı kayıtlar silinmiş olabilir; bağlantını kontrol edip tekrar dene.',
    en: 'All history could not be deleted. Some records may already be removed; check your connection and try again.',
  );
  String get deleteAccountAndData =>
      pick(tr: 'Hesabı ve Verileri Sil', en: 'Delete Account and Data');
  String get deleteAccountAndDataDescription => pick(
    tr: 'Anonim hesabı ve ona bağlı bütün antrenman verilerini kaldırır.',
    en: 'Removes the anonymous account and all workout data linked to it.',
  );
  String get deleteAccountTitle =>
      pick(tr: 'Hesap ve veriler silinsin mi?', en: 'Delete account and data?');
  String get deleteAccountMessage => pick(
    tr: 'Önce bütün antrenman verilerin, ardından anonim hesabın kalıcı olarak silinecek. Uygulamayı kullanmaya devam edersen yeni ve boş bir anonim hesap oluşturulur.',
    en: 'All workout data will be deleted first, followed by the anonymous account. Continuing to use the app creates a new, empty anonymous account.',
  );
  String get accountDeleteFailed => pick(
    tr: 'Hesap tamamen silinemedi. Verilerin silinmiş olabilir; bağlantını kontrol edip tekrar dene.',
    en: 'The account could not be fully deleted. Your workout data may already be removed; check your connection and try again.',
  );
  String get settingsLoadFailed =>
      pick(tr: 'Ayarlar yüklenemedi.', en: 'Settings could not be loaded.');
  String get dataLoadFailed =>
      pick(tr: 'Veriler yüklenemedi.', en: 'Data could not be loaded.');
  String get retry => pick(tr: 'Tekrar Dene', en: 'Retry');
  String get repeatSameExercise =>
      pick(tr: 'Aynı Hareketi Tekrarla', en: 'Repeat Same Exercise');
  String get loading => pick(tr: 'Yükleniyor...', en: 'Loading...');
  String get home => pick(tr: 'Ana Sayfa', en: 'Home');
  String get howToUse => pick(tr: 'Nasıl Kullanılır', en: 'How to Use');
  String get selectExercise => pick(tr: 'Hareket Seç', en: 'Select Exercise');
  String get sessionHistory =>
      pick(tr: 'Geçmiş Oturumlar', en: 'Session History');
  String get exerciseGuide => pick(tr: 'Hareket Rehberi', en: 'Exercise Guide');
  String get market => pick(tr: 'Market', en: 'Market');
  String get marketCatalogLoading =>
      pick(tr: 'Ürünler hazırlanıyor...', en: 'Preparing products...');
  String get marketCatalogLoadFailedTitle => pick(
    tr: 'Market kataloğu açılamadı',
    en: 'Market catalog could not be opened',
  );
  String get marketCatalogLoadFailedMessage => pick(
    tr: 'Yerel ürün şablonu okunamadı. Yeniden deneyebilirsin.',
    en: 'The local product template could not be read. You can try again.',
  );
  String get marketAllCategories => pick(tr: 'Tümü', en: 'All');
  String marketCategoryLabel(String categoryId) {
    return switch (categoryId) {
      'setup' => pick(tr: 'Kamera ve Kurulum', en: 'Camera and Setup'),
      'strength' => pick(tr: 'Kuvvet', en: 'Strength'),
      'mobility' => pick(tr: 'Mobilite', en: 'Mobility'),
      'accessories' => pick(
        tr: 'Antrenman Aksesuarları',
        en: 'Training Accessories',
      ),
      'apparel' => pick(tr: 'Giyim', en: 'Apparel'),
      _ => categoryId,
    };
  }

  String marketProductName(String productId) {
    return switch (productId) {
      'phone_tripod' => pick(tr: 'Telefon Tripodu', en: 'Phone Tripod'),
      'exercise_mat' => pick(tr: 'Egzersiz Matı', en: 'Exercise Mat'),
      'resistance_band_set' => pick(
        tr: 'Direnç Bandı Seti',
        en: 'Resistance Band Set',
      ),
      'mini_loop_band_set' => pick(
        tr: 'Mini Loop Band Seti',
        en: 'Mini Loop Band Set',
      ),
      'foam_roller' => pick(tr: 'Foam Roller', en: 'Foam Roller'),
      'adjustable_dumbbell' => pick(
        tr: 'Ayarlanabilir Dambıl',
        en: 'Adjustable Dumbbell',
      ),
      'training_tshirt' => pick(
        tr: 'Antrenman Tişörtü',
        en: 'Training T-Shirt',
      ),
      'training_shorts' => pick(tr: 'Antrenman Şortu', en: 'Training Shorts'),
      _ => productId,
    };
  }

  String marketProductDescription(String productId) {
    return switch (productId) {
      'phone_tripod' => pick(
        tr: 'Kamerayı sabit tutarak analiz kadrajını daha kolay korumana yardımcı olur.',
        en: 'Helps keep the camera stable and the analysis framing consistent.',
      ),
      'exercise_mat' => pick(
        tr: 'Zemin hareketlerinde daha dengeli ve konforlu bir çalışma alanı sunar.',
        en: 'Provides a more stable and comfortable surface for floor exercises.',
      ),
      'resistance_band_set' => pick(
        tr: 'Farklı direnç seviyeleriyle kuvvet çalışmalarını çeşitlendirir.',
        en: 'Adds variety to strength sessions with multiple resistance levels.',
      ),
      'mini_loop_band_set' => pick(
        tr: 'Aktivasyon, kalça ve alt vücut egzersizleri için kompakt destek sağlar.',
        en: 'Provides compact support for activation, glute, and lower-body work.',
      ),
      'foam_roller' => pick(
        tr: 'Antrenman öncesi mobilite ve antrenman sonrası gevşeme rutinlerini destekler.',
        en: 'Supports mobility before training and recovery routines afterward.',
      ),
      'adjustable_dumbbell' => pick(
        tr: 'Tek ekipmanla farklı ağırlık seviyelerinde kuvvet antrenmanı yapmayı sağlar.',
        en: 'Enables strength training at different loads with a single piece of equipment.',
      ),
      'training_tshirt' => pick(
        tr: 'Antrenman sırasında rahat hareket etmeyi destekleyen hafif spor tişörtüdür.',
        en: 'A lightweight sports T-shirt designed to support comfortable movement during training.',
      ),
      'training_shorts' => pick(
        tr: 'Hareket açıklığını kısıtlamadan antrenman yapmaya uygun spor şortudur.',
        en: 'Training shorts designed to allow unrestricted movement during exercise.',
      ),
      _ => productId,
    };
  }

  String get marketFeaturedLabel => pick(tr: 'Öne çıkan', en: 'Featured');
  String get marketTemplateProductLabel => pick(
    tr: 'Şablon ürün · Satış aktif değil',
    en: 'Template product · Sales inactive',
  );
  String get marketProductInformation =>
      pick(tr: 'Ürün bilgisi', en: 'Product information');
  String get marketTemplateProductDetailMessage => pick(
    tr: 'Bu ürün şimdilik market akışını göstermek için kullanılan yerel bir şablondur. Sepet cihaz belleğinde geçici olarak çalışır; ödeme henüz aktif değildir.',
    en: 'This product is currently a local template used to demonstrate the market flow. The cart works temporarily in device memory; payment is not active yet.',
  );
  String marketOpenProductDetails(String productName, String price) => pick(
    tr: '$productName, $price. Ürün detayını aç',
    en: '$productName, $price. Open product details',
  );
  String marketProductImageLabel(String productName) =>
      pick(tr: '$productName ürün görseli', en: '$productName product image');
  String marketProductGalleryImageLabel(
    String productName,
    int imageIndex,
    int imageCount,
  ) {
    if (imageCount <= 1) {
      return marketProductImageLabel(productName);
    }
    return pick(
      tr: '$productName ürün görseli, $imageIndex / $imageCount',
      en: '$productName product image, $imageIndex of $imageCount',
    );
  }

  String marketProductGalleryPosition(int imageIndex, int imageCount) => pick(
    tr: 'Görsel $imageIndex / $imageCount',
    en: 'Image $imageIndex of $imageCount',
  );

  String get marketPreviousProductImage =>
      pick(tr: 'Önceki ürün görseli', en: 'Previous product image');
  String get marketNextProductImage =>
      pick(tr: 'Sonraki ürün görseli', en: 'Next product image');
  String marketCartItemCount(int itemCount) =>
      pick(tr: 'Sepet, $itemCount ürün', en: 'Cart, $itemCount items');
  String marketIncreaseProductQuantity(String productName) => pick(
    tr: '$productName adedini artır',
    en: 'Increase $productName quantity',
  );
  String marketDecreaseProductQuantity(String productName) => pick(
    tr: '$productName adedini azalt',
    en: 'Decrease $productName quantity',
  );
  String marketRemoveProductFromCart(String productName) => pick(
    tr: '$productName ürününü sepetten kaldır',
    en: 'Remove $productName from cart',
  );
  String marketProductQuantityValue(String productName, int quantity) => pick(
    tr: '$productName, $quantity adet',
    en: '$productName, quantity $quantity',
  );
  String get marketCart => pick(tr: 'Sepet', en: 'Cart');
  String get marketAddToCart => pick(tr: 'Sepete ekle', en: 'Add to cart');
  String get marketAddAnotherToCart =>
      pick(tr: 'Bir tane daha ekle', en: 'Add another');
  String marketInCart(int quantity) =>
      pick(tr: 'Sepette ($quantity)', en: 'In cart ($quantity)');
  String get marketCartOverviewTitle =>
      pick(tr: 'Sepetini gözden geçir', en: 'Review your cart');
  String marketCartOverviewSummary(int itemCount, int lineCount) => pick(
    tr: '$itemCount ürün · $lineCount çeşit',
    en: '$itemCount items · $lineCount products',
  );
  String get marketCartEmptyTitle =>
      pick(tr: 'Sepetin boş', en: 'Your cart is empty');
  String get marketCartEmptyMessage => pick(
    tr: 'Ürün detayından bir şablon ürün eklediğinde burada görünecek.',
    en: 'A template product will appear here after you add it from product details.',
  );
  String get marketContinueShopping =>
      pick(tr: 'Alışverişe dön', en: 'Continue shopping');
  String get marketReturnToCart => pick(tr: 'Sepete dön', en: 'Return to cart');
  String get marketQuantity => pick(tr: 'Adet', en: 'Quantity');
  String get marketIncreaseQuantity =>
      pick(tr: 'Adedi artır', en: 'Increase quantity');
  String get marketDecreaseQuantity =>
      pick(tr: 'Adedi azalt', en: 'Decrease quantity');
  String get marketRemoveFromCart =>
      pick(tr: 'Sepetten kaldır', en: 'Remove from cart');
  String get marketSubtotal => pick(tr: 'Ara toplam', en: 'Subtotal');
  String get marketCheckoutTemplateMessage => pick(
    tr: 'Teslimat bilgilerini girerek güvenli PayTR ödeme oturumunu hazırlayabilirsin. Kart bilgileri PEA tarafından alınmaz veya saklanmaz.',
    en: 'Enter delivery details to prepare a secure PayTR payment session. PEA does not collect or store card details.',
  );
  String get marketProceedToCheckout =>
      pick(tr: 'Ödemeye geç', en: 'Continue to payment');
  String get marketCheckoutTitle =>
      pick(tr: 'Güvenli ödeme', en: 'Secure checkout');
  String get marketSecureCheckoutTitle =>
      pick(tr: 'Güvenli ödeme oturumu', en: 'Secure payment session');
  String get marketSecureCheckoutDescription => pick(
    tr: 'Teslimat bilgilerin yalnız sipariş ve PayTR ödeme oturumu için backend’e gönderilir. Kart bilgileri PEA uygulamasında alınmaz veya saklanmaz.',
    en: 'Your delivery details are sent to the backend only for the order and PayTR payment session. Card details are not collected or stored by the PEA app.',
  );
  String get marketDeliveryInformation => pick(
    tr: 'Teslimat ve iletişim bilgileri',
    en: 'Delivery and contact details',
  );
  String get marketCheckoutFullName => pick(tr: 'Ad soyad', en: 'Full name');
  String get marketCheckoutEmail => pick(tr: 'E-posta', en: 'Email');
  String get marketCheckoutPhone => pick(tr: 'Telefon', en: 'Phone');
  String get marketCheckoutAddress =>
      pick(tr: 'Teslimat adresi', en: 'Delivery address');
  String get marketCheckoutRequiredField =>
      pick(tr: 'Bu alan zorunludur.', en: 'This field is required.');
  String marketCheckoutInvalidLength(int minimum, int maximum) => pick(
    tr: '$minimum ile $maximum karakter arasında bir değer gir.',
    en: 'Enter between $minimum and $maximum characters.',
  );
  String get marketCheckoutInvalidEmail => pick(
    tr: 'Geçerli bir e-posta adresi gir.',
    en: 'Enter a valid email address.',
  );
  String get marketCheckoutInvalidPhone => pick(
    tr: 'Geçerli bir telefon numarası gir.',
    en: 'Enter a valid phone number.',
  );
  String get marketPaymentMethod =>
      pick(tr: 'PayTR güvenli ödeme', en: 'PayTR secure payment');
  String get marketPaytrPaymentMessage => pick(
    tr: 'Bilgilerin doğrulandıktan sonra backend kesin tutarı hesaplar ve PayTR ödeme oturumunu oluşturur. Kart ekranı uygulama içinde güvenli bir WebView ile açılır.',
    en: 'After validation, the backend calculates the authoritative total and creates a PayTR payment session. The card screen opens inside the app in a secure WebView.',
  );
  String get marketOrderItems => pick(tr: 'Ürünler', en: 'Items');
  String get marketCheckoutTotal => pick(tr: 'Toplam', en: 'Total');
  String get marketCheckoutTotalNote => pick(
    tr: 'Bu ekrandaki tutar yerel özettir. Ödeme oturumu oluşturulurken kesin tutar backend tarafından yeniden hesaplanır.',
    en: 'The amount on this screen is a local summary. The backend recalculates the authoritative total when creating the payment session.',
  );
  String get marketCreatePaymentSession => pick(
    tr: 'PayTR ödeme oturumu oluştur',
    en: 'Create PayTR payment session',
  );
  String get marketPaymentSessionCreating => pick(
    tr: 'Ödeme oturumu hazırlanıyor...',
    en: 'Preparing payment session...',
  );
  String get marketPaymentSessionReadyButton =>
      pick(tr: 'PayTR ödeme ekranını aç', en: 'Open PayTR payment screen');
  String get marketPaymentSessionReadyTitle =>
      pick(tr: 'PayTR oturumu hazır', en: 'PayTR session is ready');
  String get marketPaymentSessionReadyDescription => pick(
    tr: 'Sipariş ve güvenli PayTR ödeme oturumu backend tarafından oluşturuldu. Ödeme ekranını açabilirsin; sepet yalnız doğrulanmış başarılı ödeme sonrası temizlenir.',
    en: 'The order and secure PayTR payment session were created by the backend. You can open the payment screen; the cart is cleared only after a verified successful payment.',
  );
  String get marketPaymentSessionErrorTitle => pick(
    tr: 'Ödeme oturumu oluşturulamadı',
    en: 'Payment session could not be created',
  );
  String marketPaymentOrderReference(String orderId) =>
      pick(tr: 'Sipariş referansı: $orderId', en: 'Order reference: $orderId');
  String marketPaymentVerifiedTotal(String total) => pick(
    tr: 'Backend tarafından doğrulanan toplam: $total',
    en: 'Backend-verified total: $total',
  );
  String get marketPaymentConfigurationMissing => pick(
    tr: 'Ödeme servisi bu build için yapılandırılmamış. PAYTR_API_BASE_URL değerini tanımla.',
    en: 'The payment service is not configured for this build. Define PAYTR_API_BASE_URL.',
  );
  String get marketPaymentAuthenticationRequired => pick(
    tr: 'Kullanıcı oturumu doğrulanamadı. Uygulamayı yeniden açıp tekrar dene.',
    en: 'The user session could not be verified. Reopen the app and try again.',
  );
  String get marketPaymentCartChanged => pick(
    tr: 'Sepetteki ürün veya fiyat bilgisi değişti. Sepete dönüp yeniden kontrol et.',
    en: 'A product or price in the cart changed. Return to the cart and review it again.',
  );
  String get marketPaymentAlreadyFinalized => pick(
    tr: 'Bu ödeme oturumu daha önce sonuçlandırılmış.',
    en: 'This payment session has already been finalized.',
  );
  String get marketPaymentNetworkFailure => pick(
    tr: 'Ödeme servisine ulaşılamadı. Aynı güvenli işlem anahtarıyla tekrar deneyebilirsin.',
    en: 'The payment service could not be reached. You can retry with the same safe transaction key.',
  );
  String get marketPaymentSessionGenericFailure => pick(
    tr: 'Ödeme oturumu şu anda oluşturulamadı. Bilgilerini kontrol edip tekrar dene.',
    en: 'The payment session could not be created right now. Review your details and try again.',
  );
  String get marketPaytrScreenTitle =>
      pick(tr: 'PayTR ödeme', en: 'PayTR payment');
  String get marketPaytrSecureHeader => pick(
    tr: 'Kart bilgileri PayTR tarafından işlenir',
    en: 'Card details are processed by PayTR',
  );
  String get marketPaytrCheckStatus =>
      pick(tr: 'Ödeme durumunu kontrol et', en: 'Check payment status');
  String get marketPaytrVerifyingMessage => pick(
    tr: 'Ödeme sonucu backend callback kaydından doğrulanıyor...',
    en: 'The payment result is being verified from the backend callback record...',
  );
  String get marketPaytrPaidTitle =>
      pick(tr: 'Ödeme doğrulandı', en: 'Payment verified');
  String get marketPaytrPaidMessage => pick(
    tr: 'PayTR callback sonucu backend tarafından doğrulandı. Sipariş ödendi olarak kaydedildi ve sepet temizlendi.',
    en: 'The PayTR callback result was verified by the backend. The order was recorded as paid, and the cart was cleared.',
  );
  String get marketPaytrFailedTitle =>
      pick(tr: 'Ödeme başarısız', en: 'Payment failed');
  String get marketPaytrFailedMessage => pick(
    tr: 'Backend ödeme girişimini başarısız olarak doğruladı. Sepetin korunuyor.',
    en: 'The backend verified the payment attempt as failed. Your cart is preserved.',
  );
  String get marketPaytrUnknownTitle =>
      pick(tr: 'Sonuç henüz kesinleşmedi', en: 'Result not confirmed yet');
  String get marketPaytrUnknownMessage => pick(
    tr: 'Callback sonucu henüz backend kaydına ulaşmamış olabilir. Sepetin korunuyor; biraz sonra tekrar kontrol et.',
    en: 'The callback result may not have reached the backend record yet. Your cart is preserved; check again shortly.',
  );
  String get marketPaytrStatusError => pick(
    tr: 'Ödeme durumu şu anda doğrulanamadı. Sepetin korunuyor ve tekrar kontrol edebilirsin.',
    en: 'The payment status could not be verified right now. Your cart is preserved, and you can check again.',
  );
  String get marketPaytrWebErrorTitle => pick(
    tr: 'Ödeme sayfası yüklenemedi',
    en: 'Payment page could not be loaded',
  );
  String get marketPaytrWebErrorMessage => pick(
    tr: 'PayTR ödeme sayfası yüklenirken bir bağlantı hatası oluştu. Sayfayı yenileyebilir veya ödeme durumunu kontrol edebilirsin.',
    en: 'A connection error occurred while loading the PayTR payment page. You can reload the page or check the payment status.',
  );
  String get marketPaytrBlockedNavigation => pick(
    tr: 'Güvenli olmayan ödeme bağlantısı engellendi.',
    en: 'An unsafe payment link was blocked.',
  );
  String get marketPaytrReload => pick(tr: 'Sayfayı yenile', en: 'Reload page');
  String get marketPaytrReturnToMarket =>
      pick(tr: 'Markete dön', en: 'Return to market');
  String get marketPaytrExitTitle =>
      pick(tr: 'Ödeme ekranından çıkılsın mı?', en: 'Leave payment screen?');
  String get marketPaytrExitMessage => pick(
    tr: 'Ödeme işlemi devam ediyor olabilir. Çıkarsan sepetin korunur ve sonucu daha sonra yeniden kontrol edebilirsin.',
    en: 'The payment may still be processing. If you leave, your cart is preserved, and you can check the result again later.',
  );
  String get marketPaytrExitAction =>
      pick(tr: 'Ödeme ekranından çık', en: 'Leave payment screen');

  String get marketCheckoutEmptyTitle =>
      pick(tr: 'Sipariş özeti hazır değil', en: 'Order summary is not ready');
  String get marketCheckoutEmptyMessage => pick(
    tr: 'Sipariş özetini görmek için önce sepete bir ürün eklemelisin.',
    en: 'Add an item to the cart before reviewing the order summary.',
  );
  String get workoutMenu => pick(tr: 'Antrenman menüsü', en: 'Workout menu');
  String get achievements => pick(tr: 'Başarılar', en: 'Achievements');
  String get goals => pick(tr: 'Hedefler', en: 'Goals');
  String get open => pick(tr: 'Açık', en: 'Unlocked');
  String get locked => pick(tr: 'Kilitli', en: 'Locked');
  String get comingSoon => pick(tr: 'Yakında', en: 'Coming soon');
  String get completed => pick(tr: 'Tamamlandı', en: 'Completed');

  // Authentication
  String get preparingSession =>
      pick(tr: 'Oturum hazırlanıyor...', en: 'Preparing session...');
  String get sessionPreparationFailed => pick(
    tr: 'Kullanıcı oturumu hazırlanamadı.',
    en: 'User session could not be prepared.',
  );

  // Home
  String get homeReadyPrompt => pick(
    tr: 'Bugünkü formunu takip etmeye hazır mısın?',
    en: 'Ready to track your form today?',
  );
  String greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) {
      return pick(tr: 'Günaydın', en: 'Good morning');
    }
    if (hour >= 12 && hour < 17) {
      return pick(tr: 'İyi öğlenler', en: 'Good afternoon');
    }
    if (hour >= 17 && hour < 22) {
      return pick(tr: 'İyi akşamlar', en: 'Good evening');
    }
    return pick(tr: 'İyi geceler', en: 'Good night');
  }

  String get weeklyGoal => pick(tr: 'Aktif Hedef', en: 'Active Goal');
  String get weeklyGoalEmpty => pick(
    tr: 'Kendine uygun bir hedef seç ve ilerlemeni takip et.',
    en: 'Choose a goal that fits you and track your progress.',
  );
  String get achievementsEmptyPreview => pick(
    tr: 'Rozetlerin analizlerini tamamladıkça açılır.',
    en: 'Your badges unlock as you complete analyses.',
  );
  String get exerciseDistribution =>
      pick(tr: 'Egzersiz Dağılımı', en: 'Exercise Distribution');
  String get exerciseDistributionSubtitle => pick(
    tr: 'Oturumlarının hareketlere göre dağılımı',
    en: 'How your sessions are distributed across exercises',
  );
  String get exerciseDistributionEmpty => pick(
    tr: 'Kaydedilen oturumların hareket dağılımı burada toplanır.',
    en: 'The exercise distribution of saved sessions will appear here.',
  );
  String get exerciseDistributionOther => pick(tr: 'Diğer', en: 'Other');
  String exerciseDistributionOtherCount(int exerciseCount) =>
      pick(tr: 'Diğer ($exerciseCount)', en: 'Other ($exerciseCount)');
  String get aiCoach => 'AI Coach';
  String get aiCoachComingSoonDescription => pick(
    tr: 'Form analizi, günlük öneriler ve antrenman ipuçları yakında burada olacak.',
    en: 'Form analysis, daily suggestions, and workout tips will be available here soon.',
  );
  String get chooseExerciseAndStart => pick(
    tr: 'Hareket seç ve analize başla',
    en: 'Choose an exercise and start analysis',
  );
  String startExerciseAnalysis(String exerciseName) => pick(
    tr: '$exerciseName analizine başla',
    en: 'Start $exerciseName analysis',
  );
  String get startPreparationCheck =>
      pick(tr: 'Hazırlığı Başlat', en: 'Start Preparation');
  String get chooseExerciseFirstStep => pick(
    tr: 'İlk adımda hangi hareketi analiz edeceğini seç.',
    en: 'First choose which exercise you want to analyze.',
  );
  String get continueToPreparation => pick(
    tr: 'Tek dokunuşla izin ve hazırlık akışına geç.',
    en: 'Continue to permissions and preparation with one tap.',
  );
  String get changeExercise =>
      pick(tr: 'Hareketi Değiştir', en: 'Change Exercise');
  String get viewSupportedExercises =>
      pick(tr: 'Desteklenen hareketleri gör', en: 'View supported exercises');
  String get chooseDifferentAnalysis => pick(
    tr: 'Farklı bir analiz hattı seç',
    en: 'Choose a different analysis',
  );
  String get techniqueTipsAndMistakes =>
      pick(tr: 'Teknik ipuçları ve hatalar', en: 'Technique tips and mistakes');
  String get savedAnalyses =>
      pick(tr: 'Kaydedilmiş analizler', en: 'Saved analyses');
  String get plannedWorkout =>
      pick(tr: 'Planlı Antrenman', en: 'Planned Workout');
  String get plannedWorkoutSubtitle =>
      pick(tr: 'Set, tur ve hedef akışı', en: 'Sets, rounds, and target flow');
  String get assessment => pick(tr: 'Kamera Ölçümü', en: 'Camera Measurement');
  String get assessmentSubtitle => pick(
    tr: 'Squat, tek ayak duruşu ve omuz hareketi',
    en: 'Squat, single-leg stance, and shoulder movement',
  );
  String selectedExercise(String exerciseName) => pick(
    tr: 'Seçili hareket: $exerciseName',
    en: 'Selected exercise: $exerciseName',
  );
  String get noExerciseSelected =>
      pick(tr: 'Henüz hareket seçilmedi', en: 'No exercise selected yet');
  String get quickStartUsesSelection => pick(
    tr: 'Hızlı başlatma bu hareket üzerinden devam eder.',
    en: 'Quick start will continue with this exercise.',
  );
  String get quickStartNeedsSelection => pick(
    tr: 'Hızlı başlatma için önce analiz edeceğin hareketi seç.',
    en: 'Choose an exercise before using quick start.',
  );
  String get change => pick(tr: 'Değiştir', en: 'Change');
  String get select => pick(tr: 'Seç', en: 'Select');
  String get progressWillAppearHere => pick(
    tr: 'İlerlemen burada birikecek',
    en: 'Your progress will build up here',
  );
  String get firstAnalysisProgressDescription => pick(
    tr: 'İlk analizini tamamladığında oturumların ve haftalık özetin burada görünür.',
    en: 'Your sessions and weekly summary will appear here after your first analysis.',
  );
  String get totalAnalyses => pick(tr: 'Toplam Analiz', en: 'Total Analyses');
  String get thisWeek => pick(tr: 'Bu Hafta', en: 'This Week');
  String get homeOverview =>
      pick(tr: 'İlerleme Özeti', en: 'Progress Overview');
  String get homeOverviewSubtitle => pick(
    tr: 'Kaydedilmiş oturumlarından doğrulanmış özet',
    en: 'A verified summary from your saved sessions',
  );
  String get recentSession => pick(tr: 'Son Oturum', en: 'Latest Session');
  String get recentSessionSubtitle => pick(
    tr: 'En son tamamladığın kayıtlı analiz',
    en: 'Your most recently completed saved analysis',
  );
  String get openSession => pick(tr: 'Oturumu Aç', en: 'Open Session');
  String get quickFlows => pick(tr: 'Diğer Akışlar', en: 'More Workflows');
  String get cameraBasedAnalysis => pick(
    tr: 'Kamera tabanlı hareket analizi',
    en: 'Camera-based movement analysis',
  );
  String get homeDataRetryDescription => pick(
    tr: 'Kaydedilmiş oturumlarını yeniden yüklemek için tekrar dene.',
    en: 'Try again to reload your saved sessions.',
  );

  // Achievements
  String get achievementsLoadFailed => pick(
    tr: 'Başarılar yüklenemedi. Lütfen daha sonra tekrar dene.',
    en: 'Achievements could not be loaded. Please try again later.',
  );
  String get achievementsHeaderTitle => pick(
    tr: 'İlerlemeni ve açılan rozetleri burada göreceksin',
    en: 'Track your progress and unlocked badges here',
  );
  String get achievementsHeaderSubtitle => pick(
    tr: 'Analizlerini tamamladıkça rozetlerin burada açılır.',
    en: 'Badges unlock here as you complete your analyses.',
  );
  String achievementsEmptyMessage(bool hasError) => hasError
      ? pick(
          tr: 'Rozetler şu an hazırlanamadı. Daha sonra tekrar bakabilirsin.',
          en: 'Badges are unavailable right now. Please check again later.',
        )
      : pick(
          tr: 'İlk analizini tamamladığında rozetlerin burada görünür.',
          en: 'Your badges will appear here after you complete your first analysis.',
        );
  String achievementTitle(String id, {String? fallback}) {
    return switch (id) {
      'first_analysis' => pick(tr: 'İlk Analiz', en: 'First Analysis'),
      'score_90_plus' => pick(tr: '90+ Skor', en: '90+ Score'),
      'hundred_reps' => pick(tr: '100 Tekrar', en: '100 Reps'),
      'ten_sessions' => pick(tr: '10 Oturum', en: '10 Sessions'),
      _ => fallback ?? id,
    };
  }

  String achievementDescription(String id, {String? fallback}) {
    return switch (id) {
      'first_analysis' => pick(
        tr: 'İlk canlı analiz oturumunu tamamladın.',
        en: 'Complete your first live analysis session.',
      ),
      'score_90_plus' => pick(
        tr: 'Yüksek form kalitesiyle güçlü bir oturum çıkar.',
        en: 'Complete a strong session with high form quality.',
      ),
      'hundred_reps' => pick(
        tr: 'Toplam tekrar hacmini istikrarlı şekilde artır.',
        en: 'Build your total rep volume consistently.',
      ),
      'ten_sessions' => pick(
        tr: 'Antrenman geçmişini büyüt ve ritmini koru.',
        en: 'Build your workout history and keep your rhythm.',
      ),
      _ => fallback ?? id,
    };
  }

  String achievementRequirement(String id, {String? fallback}) {
    return switch (id) {
      'first_analysis' => pick(
        tr: '1 analiz tamamla',
        en: 'Complete 1 analysis',
      ),
      'score_90_plus' => pick(
        tr: 'Bir oturumda 90+ en iyi skor al',
        en: 'Reach a best score of 90+ in one session',
      ),
      'hundred_reps' => pick(
        tr: 'Toplam 100 tekrar tamamla',
        en: 'Complete 100 total reps',
      ),
      'ten_sessions' => pick(
        tr: '10 analiz oturumu tamamla',
        en: 'Complete 10 analysis sessions',
      ),
      _ => fallback ?? id,
    };
  }

  // Goals
  String get goalsLoadFailed => pick(
    tr: 'Hedefler yüklenemedi. Lütfen daha sonra tekrar dene.',
    en: 'Goals could not be loaded. Please try again later.',
  );
  String get goalsHeaderTitle =>
      pick(tr: 'Hedefini sen belirle', en: 'Choose your own goal');
  String get goalsHeaderSubtitle => pick(
    tr: 'Sana uygun tek bir hedef seç, değerini düzenle ve ilerlemeni sade biçimde takip et.',
    en: 'Choose one goal that fits you, adjust its target, and track progress without clutter.',
  );
  String get goalsSignInTitle =>
      pick(tr: 'Hedefler için oturum açmalısın', en: 'Sign in to use goals');
  String get goalsSignInMessage => pick(
    tr: 'Hedeflerini kaydetmek ve cihazlar arasında korumak için hesabınla oturum aç.',
    en: 'Sign in to save your goals and keep them across devices.',
  );
  String get activeGoal => pick(tr: 'Aktif hedef', en: 'Active goal');
  String get activeGoalDescription => pick(
    tr: 'Ana ekranda yalnızca bu hedef gösterilir.',
    en: 'Only this goal appears on Home.',
  );
  String get noActiveGoalTitle =>
      pick(tr: 'Aktif hedefin yok', en: 'No active goal');
  String get noActiveGoalMessage => pick(
    tr: 'Aşağıdaki önerilerden birini seçip hedef değerini kendine göre ayarla.',
    en: 'Choose a suggestion below and adjust the target to fit you.',
  );
  String get suggestedGoals =>
      pick(tr: 'Hedef önerileri', en: 'Goal suggestions');
  String get suggestedGoalsDescription => pick(
    tr: 'Değerler başlangıç önerisidir; başlamadan önce değiştirebilirsin.',
    en: 'These are starting suggestions; you can change the value before activating one.',
  );
  String get pausedGoals =>
      pick(tr: 'Duraklatılan hedefler', en: 'Paused goals');
  String get pausedGoalsDescription => pick(
    tr: 'İstediğin hedefe daha sonra kaldığın yerden devam edebilirsin.',
    en: 'You can resume any goal later.',
  );
  String get startGoal => pick(tr: 'Başlat', en: 'Start');
  String get createGoal => pick(tr: 'Hedef oluştur', en: 'Create goal');
  String get editGoal => pick(tr: 'Düzenle', en: 'Edit');
  String get pauseGoal => pick(tr: 'Duraklat', en: 'Pause');
  String get resumeGoal => pick(tr: 'Devam et', en: 'Resume');
  String get saveChanges =>
      pick(tr: 'Değişiklikleri kaydet', en: 'Save changes');
  String get goalSaved => pick(tr: 'Hedef kaydedildi.', en: 'Goal saved.');
  String get goalPaused => pick(tr: 'Hedef duraklatıldı.', en: 'Goal paused.');
  String get goalSaveFailed => pick(
    tr: 'Hedef kaydedilemedi. Lütfen tekrar dene.',
    en: 'The goal could not be saved. Please try again.',
  );
  String get goalTargetLabel => pick(tr: 'Hedef değeri', en: 'Target value');
  String get goalTargetInvalid => pick(
    tr: 'Bu hedef için geçerli aralıkta bir değer gir.',
    en: 'Enter a value within the allowed range for this goal.',
  );
  String goalTargetRange(String minimum, String maximum) => pick(
    tr: 'Geçerli aralık: $minimum–$maximum',
    en: 'Allowed range: $minimum–$maximum',
  );
  String get goalTargetCanChange => pick(
    tr: 'Başlamadan önce hedef değerini değiştirebilirsin.',
    en: 'You can change the target before starting.',
  );
  String get startingGoalPausesCurrent => pick(
    tr: 'Bu hedefi başlatınca mevcut aktif hedefin duraklatılır.',
    en: 'Starting this goal pauses your current active goal.',
  );
  String get goalProgressUnavailable => pick(
    tr: 'Oturum verileri şu an alınamadığı için hedef ilerlemesi geçici olarak gösterilemiyor.',
    en: 'Goal progress is temporarily unavailable because session data could not be loaded.',
  );
  String get goalProgressUnavailableShort =>
      pick(tr: 'İlerleme şu an alınamıyor', en: 'Progress unavailable');

  String userGoalTitle(String typeId, double targetValue, {String? fallback}) {
    final target = _formatGoalNumber(targetValue);
    return switch (typeId) {
      'weeklySessions' => pick(
        tr: 'Haftada $target analiz',
        en: '$target analyses per week',
      ),
      'weeklyReps' => pick(
        tr: 'Haftada $target tekrar',
        en: '$target reps per week',
      ),
      'averageScore' => pick(
        tr: 'Ortalama skor hedefi: $target',
        en: 'Average score target: $target',
      ),
      _ => fallback ?? typeId,
    };
  }

  String userGoalDescription(String typeId, {String? fallback}) {
    return switch (typeId) {
      'weeklySessions' => pick(
        tr: 'Bu hafta tamamlamak istediğin analiz sayısını belirle.',
        en: 'Set how many analyses you want to complete this week.',
      ),
      'weeklyReps' => pick(
        tr: 'Haftalık tekrar hacmini kendi programına göre belirle.',
        en: 'Set a weekly repetition target that fits your plan.',
      ),
      'averageScore' => pick(
        tr: 'Güvenilir ölçümlerdeki ortalama form göstergesi için hedef belirle.',
        en: 'Set a target for your average form indicator from reliable measurements.',
      ),
      _ => fallback ?? '',
    };
  }

  String userGoalUnit(String typeId, {String? fallback}) {
    return switch (typeId) {
      'weeklySessions' => pick(tr: 'analiz', en: 'analyses'),
      'weeklyReps' => pick(tr: 'tekrar', en: 'reps'),
      'averageScore' => pick(tr: 'skor', en: 'score'),
      _ => fallback ?? '',
    };
  }

  String _formatGoalNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    final formatted = value.toStringAsFixed(1);
    return isTurkish ? formatted.replaceAll('.', ',') : formatted;
  }

  String goalsEmptyMessage(bool hasError) => hasError
      ? pick(
          tr: 'Hedefler şu an hazırlanamadı. Daha sonra tekrar bakabilirsin.',
          en: 'Goals are unavailable right now. Please check again later.',
        )
      : pick(
          tr: 'İlk analizini tamamladığında hedef ilerlemen burada görünür.',
          en: 'Your goal progress will appear here after your first analysis.',
        );
  String goalTitle(String id, {String? fallback}) {
    return switch (id) {
      'weekly_analysis_count' => pick(
        tr: 'Haftalık 5 analiz',
        en: '5 analyses per week',
      ),
      'average_score_85' => pick(
        tr: 'Ortalama skoru 85 üstüne çıkar',
        en: 'Raise average score above 85',
      ),
      'total_reps_200' => pick(
        tr: 'Haftalık 200 tekrar',
        en: '200 reps per week',
      ),
      _ => fallback ?? id,
    };
  }

  String goalDescription(String id, {String? fallback}) {
    return switch (id) {
      'weekly_analysis_count' => pick(
        tr: 'Bu hafta en az 5 canlı analiz tamamla.',
        en: 'Complete at least 5 live analyses this week.',
      ),
      'average_score_85' => pick(
        tr: 'Form kalitesini koruyarak ortalama skorunu yükselt.',
        en: 'Raise your average score while maintaining form quality.',
      ),
      'total_reps_200' => pick(
        tr: 'Haftalık toplam tekrar hacmini kontrollü şekilde artır.',
        en: 'Increase your weekly total rep volume in a controlled way.',
      ),
      _ => fallback ?? id,
    };
  }

  String goalUnit(String id, {String? fallback}) {
    return switch (id) {
      'weekly_analysis_count' => pick(tr: 'analiz', en: 'analyses'),
      'average_score_85' => pick(tr: 'skor', en: 'score'),
      'total_reps_200' => pick(tr: 'tekrar', en: 'reps'),
      _ => fallback ?? '',
    };
  }

  // Chat shell
  String get aiCoachSubtitle => pick(
    tr: 'Form, tempo ve antrenman önerileri için demo sohbet alanı.',
    en: 'Demo chat for form, tempo, and workout suggestions.',
  );
  String get coachInputHint =>
      pick(tr: 'Coach’a bir soru yaz...', en: 'Ask the coach a question...');
  String get messagesLoadFailed => pick(
    tr: 'Mesajlar yüklenemedi. Lütfen tekrar dene.',
    en: 'Messages could not be loaded. Please try again.',
  );
  String get messageSendFailed => pick(
    tr: 'Mesaj gönderilemedi. Lütfen tekrar dene.',
    en: 'Message could not be sent. Please try again.',
  );

  // How to use
  String get quickFlow => pick(tr: 'Kısa Akış', en: 'Quick Flow');
  String get smallTips => pick(tr: 'Küçük İpuçları', en: 'Quick Tips');
  String get howToUseIntroTitle => pick(
    tr: 'Antrenmanını daha okunur hale getir',
    en: 'Make your workout easier to understand',
  );
  String get howToUseIntroBody => pick(
    tr: 'Bu uygulama, hareket formunu kameradan takip ederek tekrar, skor ve temel geri bildirim üretir. Oturum sonunda sonuçlarını kaydeder, böylece ilerlemeni sonradan inceleyebilirsin.',
    en: 'This app tracks your movement form through the camera to produce rep counts, scores, and basic feedback. It saves your results at the end of the session so you can review your progress later.',
  );
  String get chooseExerciseStep =>
      pick(tr: 'Hareketi seç', en: 'Choose an exercise');
  String get chooseExerciseStepBody => pick(
    tr: 'Analiz için hazır olan hareketle devam et.',
    en: 'Continue with an exercise that is ready for analysis.',
  );
  String get positionCameraStep =>
      pick(tr: 'Kamerayı konumla', en: 'Position the camera');
  String get positionCameraStepBody => pick(
    tr: 'Vücudun kadrajda net görünsün, telefon sabit kalsın.',
    en: 'Keep your whole body clearly visible and the phone stable.',
  );
  String get startAnalysisStep =>
      pick(tr: 'Analizi başlat', en: 'Start the analysis');
  String get startAnalysisStepBody => pick(
    tr: 'Hareketi kontrollü yap, anlık geri bildirimi takip et.',
    en: 'Move with control and follow the live feedback.',
  );
  String get reviewSummaryStep =>
      pick(tr: 'Özetini incele', en: 'Review your summary');
  String get reviewSummaryStepBody => pick(
    tr: 'Oturum sonunda skorunu ve tekrarlarını gözden geçir.',
    en: 'Review your score and reps at the end of the session.',
  );
  String get tipFullBodyVisible => pick(
    tr: 'Tüm vücudunu mümkün olduğunca kadrajda tut.',
    en: 'Keep your whole body in frame whenever possible.',
  );
  String get tipStableCamera => pick(
    tr: 'Telefonu sabit bir yüzeye yerleştir.',
    en: 'Place the phone on a stable surface.',
  );
  String get tipLighting => pick(
    tr: 'Eklem noktalarının seçilebilmesi için yeterli ışık kullan.',
    en: 'Use enough light for your joints to remain visible.',
  );
  String get tipControlledMovement => pick(
    tr: 'Tekrarları kontrollü yap; hızlı hareket ölçümü zorlaştırabilir.',
    en: 'Perform reps with control; moving too quickly can reduce measurement quality.',
  );

  // Exercise selection / guide shell
  String get exerciseDiscoveryTitle =>
      pick(tr: 'Hareketini keşfet', en: 'Discover your movement');
  String get exerciseDiscoveryBody => pick(
    tr: 'Kameralı analize hazır hareketleri ara, hedef bölgeye göre filtrele ve doğru akışı seç.',
    en: 'Search camera-ready exercises, filter by target area, and choose the right flow.',
  );
  String analysisReadyCount(int count) =>
      pick(tr: '$count analiz hazır', en: '$count analysis ready');
  String guideLibraryCount(int count) =>
      pick(tr: '$count rehber', en: '$count guides');
  String get exerciseGuideIntroTitle =>
      pick(tr: 'Tekniği önce gör', en: 'See the technique first');
  String get exerciseGuideIntroBody => pick(
    tr: 'Kurulum, teknik ipuçları ve yaygın hataları tek yerde incele.',
    en: 'Review setup, technique cues, and common mistakes in one place.',
  );
  String get searchGuideHint => pick(
    tr: 'Hareket, amaç veya teknik ipucu ara',
    en: 'Search exercises, purpose, or technique cues',
  );
  String get guideAvailable => pick(tr: 'Rehber hazır', en: 'Guide available');
  String get startAnalysis => pick(tr: 'Analizi başlat', en: 'Start analysis');
  String get openGuide => pick(tr: 'Rehberi aç', en: 'Open guide');
  String get noGuideResults => pick(
    tr: 'Bu filtrelerle rehber bulunamadı',
    en: 'No guides match these filters',
  );
  String get noGuideResultsBody => pick(
    tr: 'Arama metnini veya zorluk filtresini değiştir.',
    en: 'Change the search text or difficulty filter.',
  );
  String get clearGuideFilters =>
      pick(tr: 'Rehber filtrelerini temizle', en: 'Clear guide filters');

  String get searchExercises => pick(tr: 'Hareket ara', en: 'Search exercises');
  String get searchExercisesHint => pick(
    tr: 'Hareket adı veya hedef bölge ara',
    en: 'Search by exercise or target area',
  );
  String get exerciseCategories => pick(tr: 'Hedef bölge', en: 'Target area');
  String get lowerBody => pick(tr: 'Alt Vücut', en: 'Lower Body');
  String get upperBody => pick(tr: 'Üst Vücut', en: 'Upper Body');
  String get core => 'Core';
  String get fullBody => pick(tr: 'Tüm Vücut', en: 'Full Body');
  String get recentExercises =>
      pick(tr: 'Son Kullanılanlar', en: 'Recently Used');
  String get allExercises => pick(tr: 'Tüm Hareketler', en: 'All Exercises');
  String exerciseResultCount(int count) => pick(
    tr: '$count hareket',
    en: count == 1 ? '1 exercise' : '$count exercises',
  );
  String get noExercisesFound =>
      pick(tr: 'Hareket bulunamadı', en: 'No exercises found');
  String get noExercisesFoundBody => pick(
    tr: 'Arama metnini veya hedef bölge filtresini değiştir.',
    en: 'Change the search text or target-area filter.',
  );
  String get exerciseSearchResults =>
      pick(tr: 'Arama Sonuçları', en: 'Search Results');
  String get clearSearch => pick(tr: 'Aramayı temizle', en: 'Clear search');
  String get clearExerciseFilters =>
      pick(tr: 'Filtreleri temizle', en: 'Clear filters');
  String get analysisActive => pick(tr: 'Analiz aktif', en: 'Analysis active');
  String get guideOnlyForNow =>
      pick(tr: 'Şimdilik rehber içeriği', en: 'Guide content only for now');
  String get exerciseNotActiveForAnalysis => pick(
    tr: 'Bu hareket şu an analiz için aktif değil. Rehberden inceleyebilirsin.',
    en: 'This exercise is not active for analysis yet. You can review it in the guide.',
  );
  String get all => pick(tr: 'Tümü', en: 'All');
  String get purpose => pick(tr: 'Amaç', en: 'Purpose');
  String get setup => pick(tr: 'Kurulum', en: 'Setup');
  String get techniqueTips => pick(tr: 'Teknik İpuçları', en: 'Technique Tips');
  String get commonMistakes =>
      pick(tr: 'Yaygın Hatalar', en: 'Common Mistakes');
  String source(String label) {
    final localizedLabel = isTurkish
        ? switch (label) {
            'Technique reference' => 'Teknik referans',
            'Beginner technique video' => 'Başlangıç teknik videosu',
            'Simultaneous standing curl demo' =>
              'Eş zamanlı ayakta biseps büküş demosu',
            'Bench dip technique reference' => 'Bench dip teknik referansı',
            'Exercise technique search' => 'Egzersiz teknik araması',
            _ => label,
          }
        : label;
    return pick(tr: 'Kaynak: $localizedLabel', en: 'Source: $localizedLabel');
  }

  String get watchOnYoutube =>
      pick(tr: 'YouTube’da İzle', en: 'Watch on YouTube');
  String get videoLinkOpenFailed => pick(
    tr: 'Video bağlantısı açılamadı.',
    en: 'The video link could not be opened.',
  );
  String get noGuideContentForDifficulty => pick(
    tr: 'Bu zorlukta rehber içeriği bulunamadı.',
    en: 'No guide content was found for this difficulty.',
  );
  String difficultyLabel(String name) {
    return switch (name) {
      'beginner' => pick(tr: 'Başlangıç', en: 'Beginner'),
      'intermediate' => pick(tr: 'Orta', en: 'Intermediate'),
      'advanced' => pick(tr: 'İleri', en: 'Advanced'),
      _ => name,
    };
  }

  String exerciseTitle(String id) {
    return switch (id) {
      'squat' => 'Squat',
      'plank' => 'Plank',
      'hollow_hold' => 'Hollow Hold',
      'lunge' => pick(tr: 'Sabit Lunge', en: 'Stationary Lunge'),
      'push_up' => pick(tr: 'Şınav', en: 'Push-up'),
      'sit_up' => pick(tr: 'Mekik', en: 'Sit-up'),
      'crunch' => 'Crunch',
      'reverse_crunch' => pick(tr: 'Ters Mekik', en: 'Reverse Crunch'),
      'biceps_curl' => pick(tr: 'Biseps Curl', en: 'Biceps Curl'),
      'lying_leg_raise' => pick(
        tr: 'Yatarak Bacak Kaldırma',
        en: 'Lying Leg Raise',
      ),
      'bent_knee_leg_raise' => pick(
        tr: 'Dizler Bükülü Bacak Kaldırma',
        en: 'Bent-Knee Leg Raise',
      ),
      'standing_hamstring_curl' => pick(
        tr: 'Ayakta Arka Bacak Curl',
        en: 'Standing Hamstring Curl',
      ),
      'standing_hip_abduction' => pick(
        tr: 'Ayakta Kalça Abdüksiyonu',
        en: 'Standing Hip Abduction',
      ),
      'triceps_dip' => pick(tr: 'Bench Dip', en: 'Bench Dip'),
      'romanian_deadlift' => pick(
        tr: 'Romen Deadlift',
        en: 'Romanian Deadlift',
      ),
      'good_morning' => 'Good Morning',
      'lateral_raise' => pick(tr: 'Yana Kol Kaldırma', en: 'Lateral Raise'),
      'shoulder_press' => pick(tr: 'Omuz Press', en: 'Shoulder Press'),
      'overhead_triceps_extension' => pick(
        tr: 'Baş Üstü Triseps Extension',
        en: 'Overhead Triceps Extension',
      ),
      'upright_row' => pick(tr: 'Dik Çekiş', en: 'Upright Row'),
      'calf_raise' => pick(tr: 'Baldır Kaldırma', en: 'Calf Raise'),
      'front_raise' => pick(tr: 'Öne Kol Kaldırma', en: 'Front Raise'),
      'glute_bridge' => pick(tr: 'Kalça Köprüsü', en: 'Glute Bridge'),
      'wall_sit' => pick(tr: 'Duvar Oturuşu', en: 'Wall Sit'),
      'side_plank' => pick(tr: 'Yan Plank', en: 'Side Plank'),
      'jumping_jack' => 'Jumping Jack',
      'standing_hip_extension' => pick(
        tr: 'Ayakta Kalça Ekstansiyonu',
        en: 'Standing Hip Extension',
      ),
      'standing_knee_raise' => pick(
        tr: 'Ayakta Diz Kaldırma',
        en: 'Standing Knee Raise',
      ),
      'standing_straight_leg_raise' => pick(
        tr: 'Ayakta Düz Bacak Kaldırma',
        en: 'Standing Straight-Leg Raise',
      ),
      'v_up' => 'V-Up',
      'frog_pump' => 'Frog Pump',
      'lying_triceps_extension' => pick(
        tr: 'Yatarak Triseps Extension',
        en: 'Lying Triceps Extension',
      ),
      'floor_chest_press' => pick(
        tr: 'Yerde Göğüs Press',
        en: 'Floor Chest Press',
      ),
      'y_raise' => pick(tr: 'Y Kaldırış', en: 'Y Raise'),
      _ =>
        id
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' '),
    };
  }

  // Workout / assessment / session surfaces
  String get close => pick(tr: 'Kapat', en: 'Close');
  String get back => pick(tr: 'Geri Dön', en: 'Go Back');
  String get openSettings => pick(tr: 'Ayarları Aç', en: 'Open Settings');
  String get checking => pick(tr: 'Kontrol Ediliyor', en: 'Checking');
  String get grantCameraPermission =>
      pick(tr: 'Kamera İzni Ver', en: 'Grant Camera Permission');
  String get cameraPermission =>
      pick(tr: 'Kamera İzni', en: 'Camera Permission');
  String get cameraPermissionRequired =>
      pick(tr: 'Kamera İzni Gerekli', en: 'Camera Permission Required');
  String get cameraPermissionRestrictedMessage => pick(
    tr: 'Bu cihazda kamera izni kısıtlanmış görünüyor. Devam etmek için cihaz ayarlarını kontrol et.',
    en: 'Camera access appears to be restricted on this device. Check the device settings to continue.',
  );
  String get cameraPermissionPermanentlyDeniedMessage => pick(
    tr: 'Kamera izni kalıcı olarak kapalı. Analize devam etmek için telefon ayarlarından kamera iznini açman gerekiyor.',
    en: 'Camera permission is permanently disabled. Enable camera access in your phone settings to continue the analysis.',
  );
  String get cameraPermissionDeniedMessage => pick(
    tr: 'Kamera izni verilmedi. Hazır olduğunda tekrar deneyebilirsin; izin verilene kadar burada güvenli şekilde bekleyeceğiz.',
    en: 'Camera permission was not granted. You can try again when you are ready; the app will wait here until permission is available.',
  );
  String get cameraPermissionPromptMessage => pick(
    tr: 'Analize başlamadan önce kamera iznine ihtiyacımız var. İzin istemek için aşağıdaki butona dokun.',
    en: 'Camera permission is required before analysis can start. Tap the button below to request access.',
  );
  String get cameraPermissionRationale => pick(
    tr: 'Vücut eklemlerini algılamak, hareket formunu analiz etmek ve tekrarları gerçek zamanlı saymak için kamera izni gerekiyor.',
    en: 'Camera access is required to detect body joints, analyze movement form, and count repetitions in real time.',
  );
  String get cameraDetectsJoints =>
      pick(tr: 'Vücut eklemlerini algılar.', en: 'Detects body joints.');
  String get cameraEvaluatesForm => pick(
    tr: 'Hareket formunu gerçek zamanlı değerlendirir.',
    en: 'Evaluates movement form in real time.',
  );
  String get cameraCountsReps => pick(
    tr: 'Doğru tekrarları saymaya yardımcı olur.',
    en: 'Helps count valid repetitions.',
  );
  String get cameraPrivacyNotice => pick(
    tr: 'Kamera görüntüleri cihazda işlenir; depolanmaz ve sunucuya gönderilmez.',
    en: 'Camera images are processed on the device; they are not stored or sent to a server.',
  );
  String get workoutDataStorageNotice => pick(
    tr: 'Tekrar, süre, skor ve teknik ölçümler antrenman geçmişin için buluta kaydedilir.',
    en: 'Repetitions, duration, scores, and technique measurements are saved to the cloud for your workout history.',
  );
  String get selectExerciseBeforeCameraTitle => pick(
    tr: 'Analiz için hareket seç',
    en: 'Choose an exercise for analysis',
  );
  String get selectExerciseBeforeCameraMessage => pick(
    tr: 'Kamera izni akışına girmeden önce hangi hareketi analiz etmek istediğini seçmelisin.',
    en: 'Choose the exercise you want to analyze before entering the camera permission flow.',
  );
  String get preparation => pick(tr: 'Hazırlık', en: 'Preparation');
  String get selectExerciseBeforePreparationTitle => pick(
    tr: 'Hazırlıktan önce hareket seç',
    en: 'Choose an exercise before preparation',
  );
  String get selectExerciseBeforePreparationMessage => pick(
    tr: 'Hazırlık ve analiz adımlarına geçmeden önce geçerli bir hareket seçimi gerekiyor.',
    en: 'A valid exercise selection is required before preparation and analysis can begin.',
  );
  String get preparationGuide => pick(tr: 'Kılavuz', en: 'Guide');
  String preparationGuideForExercise(String exerciseName) =>
      pick(tr: '$exerciseName için hazırlık', en: 'Prepare for $exerciseName');
  String get preparationGuideSteps =>
      pick(tr: 'Hızlı hazırlık adımları', en: 'Quick setup steps');
  String preparationVoiceCoachStatus({required bool enabled}) => enabled
      ? pick(
          tr: 'Sesli koç açık. Analiz sırasında anlık yönlendirmeleri duyacaksın.',
          en: 'Voice coaching is on. You will hear live guidance during analysis.',
        )
      : pick(
          tr: 'Sesli koç kapalı. Görsel yönlendirmeler çalışmaya devam eder.',
          en: 'Voice coaching is off. Visual guidance remains available.',
        );
  String get preparationCameraLoading =>
      pick(tr: 'Kamera hazırlanıyor...', en: 'Preparing the camera...');
  String get preparationCameraUnavailable =>
      pick(tr: 'Kamera henüz hazır değil', en: 'Camera is not ready yet');
  String get preparationReadinessTitle =>
      pick(tr: 'Hazırlık durumu', en: 'Setup status');
  String get preparationReadinessChecking =>
      pick(tr: 'Kontrol ediliyor', en: 'Checking');
  String get preparationReadinessNeedsAdjustment =>
      pick(tr: 'Konumunu ayarla', en: 'Adjust your position');
  String get preparationReadinessReady => pick(tr: 'Hazır', en: 'Ready');
  String get preparationGateMonitoringTitle =>
      pick(tr: 'Hazırlık kontrolü aktif', en: 'Preparation check active');
  String get preparationGateMonitoringMessage => pick(
    tr: 'Kadraja geç. Hazır olduğunda analiz otomatik başlayacak.',
    en: 'Move into the frame. Analysis will start automatically when you are ready.',
  );
  String get preparationGateCancel =>
      pick(tr: 'Hazırlığı İptal Et', en: 'Cancel Preparation');
  String get preparationGateOverrideWarning => pick(
    tr: 'Hazırlık kontrolleri tamamlanmadı. Atlayarak başlatırsan analiz sonuçları daha az güvenilir olabilir.',
    en: 'The preparation checks are incomplete. Starting anyway may make the analysis less reliable.',
  );
  String get preparationGateOverrideAction =>
      pick(tr: 'Kontrolleri Atlayarak Başlat', en: 'Start Without Checks');
  String get preparationCountdownTitle =>
      pick(tr: 'Geri sayım başladı', en: 'Countdown started');
  String get preparationCountdownMessage => pick(
    tr: 'Pozisyonunu koru. Analiz geri sayım tamamlanınca başlayacak.',
    en: 'Hold your position. Analysis will start when the countdown finishes.',
  );
  String preparationCountdownSemantics(int value) => pick(
    tr: 'Analiz $value saniye içinde başlayacak.',
    en: 'Analysis will start in $value seconds.',
  );
  String get preparationGateLaunching =>
      pick(tr: 'Analiz başlatılıyor...', en: 'Starting analysis...');
  String get preparationCheckPersonVisibility =>
      pick(tr: 'Kişi görünürlüğü', en: 'Person visibility');
  String get preparationCheckFraming => pick(tr: 'Kadraj', en: 'Framing');
  String get preparationCheckCameraView =>
      pick(tr: 'Kamera açısı', en: 'Camera view');
  String get preparationCheckStartPose =>
      pick(tr: 'Başlangıç pozisyonu', en: 'Starting position');
  String get preparationNoPersonGuidance => pick(
    tr: 'Kadraja geç ve vücudunu kameraya göster.',
    en: 'Move into the frame and let the camera see your body.',
  );
  String get preparationIncompleteCoverageGuidance => pick(
    tr: 'Gerekli eklemler görünmüyor. Vücudunun istenen bölümlerini kadraja al.',
    en: 'Some required joints are not visible. Bring the requested body areas into the frame.',
  );
  String get preparationClippedGuidance => pick(
    tr: 'Vücudunun bir bölümü kadraj dışında. Biraz geri çekil.',
    en: 'Part of your body is outside the frame. Move slightly farther back.',
  );
  String get preparationTooNearGuidance => pick(
    tr: 'Kameraya çok yakınsın. Biraz geri git.',
    en: 'You are too close to the camera. Move a little farther back.',
  );
  String get preparationTooFarGuidance => pick(
    tr: 'Kameradan çok uzaktasın. Biraz yaklaş.',
    en: 'You are too far from the camera. Move a little closer.',
  );
  String get preparationOffCenterGuidance => pick(
    tr: 'Kadrajın ortasına geç.',
    en: 'Move toward the center of the frame.',
  );
  String get preparationCameraViewCheckingGuidance => pick(
    tr: 'Omuz ve kalçalarını görünür tutup kısa süre sabit dur.',
    en: 'Keep your shoulders and hips visible and hold still briefly.',
  );
  String get preparationTurnSideGuidance => pick(
    tr: 'Sağ veya sol yanını kameraya dön.',
    en: 'Turn your left or right side toward the camera.',
  );
  String get preparationFaceCameraGuidance =>
      pick(tr: 'Doğrudan kameraya dön.', en: 'Face the camera directly.');
  String get preparationSupportedCameraViewGuidance => pick(
    tr: 'Bu açı kullanılabilir. Önerilen açı daha güvenilir sonuç verebilir.',
    en: 'This view is usable. The recommended view may produce more reliable results.',
  );
  String get preparationReadyGuidance => pick(
    tr: 'Kadraj, kamera açısı ve başlangıç pozisyonu uygun.',
    en: 'Your framing, camera view, and starting position are suitable.',
  );
  String get preparationStartPoseGuidance => pick(
    tr: 'Hareketin başlangıç pozisyonunu al ve kısa süre sabit kal.',
    en: 'Move into the exercise starting position and hold still briefly.',
  );
  String get preparationStabilizingGuidance => pick(
    tr: 'Pozisyonun uygun. Hazır durumu doğrulanırken kısa süre sabit kal.',
    en: 'Your position looks suitable. Hold still briefly while readiness is confirmed.',
  );
  String get preparationTemporarilyLostGuidance => pick(
    tr: 'Pozisyonunu yeniden algılıyoruz. Kısa süre sabit kal.',
    en: 'We are reacquiring your position. Hold still briefly.',
  );
  String get preparationReadinessErrorGuidance => pick(
    tr: 'Hazırlık kontrolü tamamlanamadı. Kamerayı yeniden dene.',
    en: 'The setup check could not be completed. Retry the camera.',
  );
  String unsupportedExerciseFallback(String selected, String active) => pick(
    tr: '$selected henüz aktif analiz için desteklenmiyor. Şimdilik $active analizi ile devam edebilirsin.',
    en: '$selected is not supported for active analysis yet. You can continue with $active analysis for now.',
  );
  String get preparationTipStablePhone => pick(
    tr: 'Telefonu sabit bir yere koy.',
    en: 'Place the phone on a stable surface.',
  );
  String get preparationTipFullBody => pick(
    tr: 'Tüm vücudun kamerada görünsün.',
    en: 'Keep your whole body visible in the camera.',
  );
  String get preparationTipLighting => pick(
    tr: 'Ortam ışığı yeterli olsun.',
    en: 'Make sure the lighting is sufficient.',
  );
  String get preparationTipControlledMovement => pick(
    tr: 'Hareketi kontrollü yap.',
    en: 'Perform the movement with control.',
  );
  String get analysisConfigLoadFailed => pick(
    tr: 'Analiz modeli hazırlanamadı. Tekrar dene; sorun sürerse hareketi yeniden seç.',
    en: 'The analysis model could not be prepared. Try again; if the problem continues, choose the exercise again.',
  );
  String get analysisConfigLoading => pick(
    tr: 'Analiz yapılandırması hazırlanıyor...',
    en: 'Preparing analysis configuration...',
  );
  String get analysisConfigRequiredMessage => pick(
    tr: 'Egzersiz ayarları hazır olmadan canlı analiz başlatılamaz.',
    en: 'Live analysis cannot start until the exercise configuration is ready.',
  );
  String get analysisRecoveringTitle =>
      pick(tr: 'Analiz yeniden hazırlanıyor', en: 'Recovering analysis');
  String get analysisRecoveringMessage => pick(
    tr: 'Geçici bir işleme hatası oluştu. Güvenli sonuç alınana kadar hareket değerlendirmesi durduruldu.',
    en: 'A temporary processing error occurred. Exercise evaluation is paused until a reliable result is available.',
  );
  String get analysisInterruptedTitle =>
      pick(tr: 'Analiz durduruldu', en: 'Analysis stopped');
  String get analysisTimeoutMessage => pick(
    tr: 'Poz algılama işlemi yanıt vermedi. Eski geri bildirimler temizlendi; analizi güvenli biçimde yeniden başlat.',
    en: 'Pose detection stopped responding. Stale feedback was cleared; restart the analysis safely.',
  );
  String get analysisRepeatedFailureMessage => pick(
    tr: 'Analiz art arda hata verdi. Yanlış yönlendirmeyi önlemek için değerlendirme durduruldu.',
    en: 'Analysis failed repeatedly. Evaluation was stopped to prevent unreliable guidance.',
  );

  // Assessment surfaces
  String get assessmentMode =>
      pick(tr: 'Kamera Ölçümleri', en: 'Camera Measurements');
  String get assessmentDisclaimer => pick(
    tr: 'Bu ekran kamera görüntüsünden yaklaşık hareket ölçümleri üretir; klinik tanı veya tıbbi değerlendirme yerine geçmez.',
    en: 'This screen estimates movement from the camera image; it does not replace a clinical diagnosis or medical assessment.',
  );
  String assessmentTitle(String typeName) {
    return switch (typeName) {
      'squat' => pick(tr: 'Squat Hareket Ölçümü', en: 'Squat Movement Check'),
      'balance' => pick(
        tr: 'Tek Ayak Duruş Ölçümü',
        en: 'Single-Leg Stance Check',
      ),
      'shoulderMobility' => pick(
        tr: 'Omuz Hareket Ölçümü',
        en: 'Shoulder Movement Check',
      ),
      _ => typeName,
    };
  }

  String get squatAssessmentSubtitle => pick(
    tr: 'Yan görünümde diz bükülmesi, squat derinliği ve gövde eğimi.',
    en: 'Knee bend, squat depth, and torso lean from a side view.',
  );
  String get balanceAssessmentSubtitle => pick(
    tr: 'Ön görünümde tek ayak duruş süresi ve görüntüdeki salınım.',
    en: 'Single-leg stance time and visible sway from a front view.',
  );
  String get shoulderAssessmentSubtitle => pick(
    tr: 'Ön görünümde kolları yana kaldırma açısı, sağ-sol farkı ve gövde yana eğimi.',
    en: 'Arm raise angles, left-right difference, and side lean from a front view.',
  );
  String get chooseStandingFoot =>
      pick(tr: 'Duruş ayağını seç', en: 'Choose the standing foot');
  String get leftFoot => pick(tr: 'Sol ayak', en: 'Left foot');
  String get rightFoot => pick(tr: 'Sağ ayak', en: 'Right foot');
  String get assessmentCameraPermissionRequired => pick(
    tr: 'Bu ölçüm için kamera izni gerekli.',
    en: 'Camera permission is required for this measurement.',
  );
  String get chooseAssessmentFirst => pick(
    tr: 'Önce bir kamera ölçümü seçmelisin.',
    en: 'Choose a camera measurement first.',
  );
  String get cameraInUseMessage => pick(
    tr: 'Kamera başka bir uygulama tarafından kullanılıyor olabilir. Diğer kamera uygulamalarını kapatıp tekrar dene.',
    en: 'The camera may be in use by another app. Close other camera apps and try again.',
  );
  String get cameraStartFailedMessage => pick(
    tr: 'Kamera başlatılamadı. Tekrar dene; sorun sürerse uygulamayı veya telefonu yeniden başlat.',
    en: 'The camera could not be started. Try again; if the problem continues, restart the app or device.',
  );
  String get viewResult => pick(tr: 'Sonucu Gör', en: 'View Result');
  String validSamples(int count) =>
      pick(tr: 'Geçerli örnek: $count', en: 'Valid samples: $count');
  String get assessmentResult =>
      pick(tr: 'Kamera ölçüm özeti', en: 'Camera Measurement Summary');
  String get cameraEstimate =>
      pick(tr: 'Kamera tahmini', en: 'Camera estimate');
  String approximateDegrees(int degrees) =>
      pick(tr: 'Yaklaşık $degrees°', en: 'About $degrees°');
  String approximateScore(int score) =>
      pick(tr: 'Yaklaşık $score / 100', en: 'About $score / 100');
  String approximateSeconds(int seconds) =>
      pick(tr: 'Yaklaşık $seconds sn', en: 'About $seconds s');
  String get insufficientMeasurement =>
      pick(tr: 'Yetersiz ölçüm', en: 'Insufficient Measurement');
  String get insufficientMeasurementDescription => pick(
    tr: 'Güvenilir bir sonuç göstermek için yeterli ve kesintisiz ölçüm alınamadı. Pozisyonunu düzenleyip tekrar deneyebilirsin.',
    en: 'There was not enough continuous measurement data to show a reliable result. Adjust your position and try again.',
  );
  String get yes => pick(tr: 'Evet', en: 'Yes');
  String get no => pick(tr: 'Hayır', en: 'No');
  String get kneeFlexion =>
      pick(tr: 'Diz bükülme açısı', en: 'Knee bend angle');
  String get hipReachedKneeHeight =>
      pick(tr: 'Kalça diz seviyesine ulaştı', en: 'Hip reached knee height');
  String get torsoInclination =>
      pick(tr: 'Gövde öne eğilme açısı', en: 'Forward torso lean');
  String get stabilityScore =>
      pick(tr: 'Denge göstergesi', en: 'Balance indicator');
  String get continuousStanceDuration =>
      pick(tr: 'Tek ayak duruş süresi', en: 'Single-leg stance time');
  String get leftMaximumElevation =>
      pick(tr: 'Sol kol kaldırma açısı', en: 'Left arm raise angle');
  String get rightMaximumElevation =>
      pick(tr: 'Sağ kol kaldırma açısı', en: 'Right arm raise angle');
  String get leftRightDifference => pick(
    tr: 'Kol açıları arasındaki fark',
    en: 'Difference between arm angles',
  );
  String get leftMaximumLateralTorsoInclination => pick(
    tr: 'Sol kol yukarıdayken gövde yana eğimi',
    en: 'Side lean with the left arm raised',
  );
  String get rightMaximumLateralTorsoInclination => pick(
    tr: 'Sağ kol yukarıdayken gövde yana eğimi',
    en: 'Side lean with the right arm raised',
  );
  String secondsValue(double seconds) => pick(
    tr: '${seconds.toStringAsFixed(1)} sn',
    en: '${seconds.toStringAsFixed(1)} s',
  );

  // Session history / report
  String get historyRequiresAnalysis => pick(
    tr: 'Geçmiş oturumları görmek için önce bir analiz başlat.',
    en: 'Start an analysis first to view session history.',
  );
  String get historyLoadFailed => pick(
    tr: 'Geçmiş oturumlar yüklenemedi. Lütfen tekrar dene.',
    en: 'Session history could not be loaded. Please try again.',
  );
  String get historyLoadMoreFailed => pick(
    tr: 'Daha fazla oturum yüklenemedi. Lütfen tekrar dene.',
    en: 'More sessions could not be loaded. Please try again.',
  );
  String get historyUnavailable =>
      pick(tr: 'Geçmiş yüklenemedi', en: 'History unavailable');
  String get noSessionsYet =>
      pick(tr: 'Henüz oturum yok', en: 'No sessions yet');
  String get savedWorkoutsAppearHere => pick(
    tr: 'Kaydedilmiş antrenmanların burada görünecek.',
    en: 'Your saved workouts will appear here.',
  );
  String get loadMore => pick(tr: 'Daha Fazla Yükle', en: 'Load More');
  String get showAllExercises =>
      pick(tr: 'Tüm hareketleri göster', en: 'Show all exercises');
  String sessionsShown(int count) => pick(
    tr: '$count oturum gösteriliyor',
    en: '$count ${count == 1 ? 'session' : 'sessions'} shown',
  );
  String get noMatchingSessions =>
      pick(tr: 'Eşleşen oturum yok', en: 'No matching sessions');
  String get noMatchingSessionsDetail => pick(
    tr: 'Bu hareket için henüz kaydedilmiş bir oturum bulunmuyor.',
    en: 'There are no saved sessions for this exercise yet.',
  );
  String scoreComparedToPrevious(int delta) {
    final value = delta > 0 ? '+$delta' : '$delta';
    return pick(tr: 'Önceki oturuma göre $value', en: '$value vs previous');
  }

  String get duration => pick(tr: 'Süre', en: 'Duration');
  String get totalHold => pick(tr: 'Toplam Tutuş', en: 'Total Hold');
  String get bestHold => pick(tr: 'En İyi Tutuş', en: 'Best Hold');
  String get interruptions => pick(tr: 'Kesinti', en: 'Breaks');
  String get reps => pick(tr: 'Tekrar', en: 'Reps');
  String get averageScoreShort => pick(tr: 'Ort. Skor', en: 'Avg. Score');
  String get averageFormRangeScoreShort =>
      pick(tr: 'Ort. Form/ROM', en: 'Avg. Form/ROM');
  String get bestShort => pick(tr: 'En İyi', en: 'Best');
  String get warnings => pick(tr: 'Uyarı', en: 'Warnings');
  String get sessionReport => pick(tr: 'Oturum Raporu', en: 'Session Report');
  String get deleteSession =>
      pick(tr: 'Bu Oturumu Sil', en: 'Delete This Session');
  String get deleteSessionTitle =>
      pick(tr: 'Oturum silinsin mi?', en: 'Delete session?');
  String get deleteSessionMessage => pick(
    tr: 'Bu antrenman ve tekrar detayları kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    en: 'This workout and its repetition details will be permanently deleted. This action cannot be undone.',
  );
  String get cancel => pick(tr: 'İptal', en: 'Cancel');
  String get delete => pick(tr: 'Sil', en: 'Delete');
  String get deleting => pick(tr: 'Siliniyor...', en: 'Deleting...');
  String get sessionDeleteFailed => pick(
    tr: 'Oturum silinemedi. Bağlantını kontrol edip tekrar dene.',
    en: 'The session could not be deleted. Check your connection and try again.',
  );
  String get repDetailsLoadFailed => pick(
    tr: 'Tekrar detayları yüklenemedi. Lütfen tekrar dene.',
    en: 'Rep details could not be loaded. Please try again.',
  );
  String get analysis => pick(tr: 'Analiz', en: 'Analysis');
  String get totalReps => pick(tr: 'Toplam Tekrar', en: 'Total Reps');
  String get averageScore => pick(tr: 'Ortalama Skor', en: 'Average Score');
  String get averageFormRangeScore => pick(
    tr: 'Ortalama Form ve Hareket Aralığı Skoru',
    en: 'Average Form and Range Score',
  );
  String get scoreView => pick(tr: 'Skor Görünümü', en: 'Score View');
  String get holdSummary => pick(tr: 'Tutuş Özeti', en: 'Hold Summary');
  String get reportSummary => pick(tr: 'Rapor Özeti', en: 'Report Summary');
  String get recommendations => pick(tr: 'Öneriler', en: 'Recommendations');
  String get repDetails => pick(tr: 'Tekrar Detayları', en: 'Rep Details');
  String get noRepDetails => pick(
    tr: 'Bu oturumda tekrar detayları kaydedilmemiş. Eski oturumlarda yalnızca özet veriler bulunabilir.',
    en: 'Rep details were not saved for this session. Older sessions may contain summary data only.',
  );
  String get showingCachedRepDetails => pick(
    tr: 'Güncel detaylar alınamadı; eldeki kayıt gösteriliyor.',
    en: 'Fresh details could not be loaded; the available saved data is shown.',
  );
  String get status => pick(tr: 'Durum', en: 'Status');
  String get score => pick(tr: 'Skor', en: 'Score');
  String get formRangeScore =>
      pick(tr: 'Form ve Hareket Aralığı Skoru', en: 'Form and Range Score');
  String get side => pick(tr: 'Taraf', en: 'Side');
  String get primaryMetric => pick(tr: 'Birincil Metrik', en: 'Primary Metric');
  String get worstForm => pick(tr: 'En Kötü Form', en: 'Worst Form');
  String get measurementConfidence =>
      pick(tr: 'Ölçüm güveni', en: 'Measurement confidence');
  String get averageMeasurementConfidence =>
      pick(tr: 'Ortalama ölçüm güveni', en: 'Average measurement confidence');
  String get measurementEvidence =>
      pick(tr: 'Ölçüm güvenilirliği', en: 'Measurement reliability');
  String get measurementQuality =>
      pick(tr: 'Ölçüm kalitesi', en: 'Measurement quality');
  String get measurementQualityHigh => pick(tr: 'Güçlü', en: 'Strong');
  String get measurementQualityModerate =>
      pick(tr: 'Yeterli', en: 'Sufficient');
  String get measurementQualityLimited => pick(tr: 'Sınırlı', en: 'Limited');
  String get measurementQualityInsufficient =>
      pick(tr: 'Yetersiz', en: 'Insufficient');
  String get measurementQualityUnavailable =>
      pick(tr: 'Bilgi yok', en: 'Unavailable');
  String get preparationCheck =>
      pick(tr: 'Hazırlık kontrolü', en: 'Preparation check');
  String get preparationPassed => pick(tr: 'Geçildi', en: 'Passed');
  String get preparationOverridden =>
      pick(tr: 'Manuel geçildi', en: 'Skipped manually');
  String get preparationUnavailable => pick(tr: 'Bilgi yok', en: 'Unavailable');
  String measurementSampleCount(int count) =>
      pick(tr: '$count ölçüm örneği', en: '$count measurement samples');
  String get measurementEvidenceWarningShort => pick(
    tr: 'Ölçüm güvenilirliği sınırlı',
    en: 'Measurement reliability is limited',
  );
  String get preparationOverrideWarningTitle => pick(
    tr: 'Hazırlık kontrolü atlandı',
    en: 'Preparation check was skipped',
  );
  String get preparationOverrideWarningMessage => pick(
    tr: 'Bu oturum geçmişte görünür ancak skor karşılaştırmalarına, hedeflere ve başarımlara dahil edilmez.',
    en: 'This session stays in history but is excluded from score comparisons, goals, and achievements.',
  );
  String get limitedMeasurementWarningTitle => pick(
    tr: 'Ölçüm güvenilirliği sınırlı',
    en: 'Measurement reliability is limited',
  );
  String get limitedMeasurementWarningMessage => pick(
    tr: 'Skor grafikte uyarıyla görünür; ortalama, rekor, hedef ve başarım hesaplarına dahil edilmez.',
    en: 'The score remains visible with a warning but is excluded from averages, records, goals, and achievements.',
  );
  String get insufficientMeasurementWarningTitle => pick(
    tr: 'Yeterli ölçüm örneği yok',
    en: 'Not enough measurement samples',
  );
  String get insufficientMeasurementWarningMessage => pick(
    tr: 'Oturum geçmişte görünür; skor trendine ve ilerleme hesaplarına dahil edilmez.',
    en: 'The session remains in history but is excluded from score trends and progress calculations.',
  );
  String get measurementConfidenceReliable =>
      pick(tr: 'Güvenilir', en: 'Reliable');
  String get measurementConfidenceLimited => pick(tr: 'Sınırlı', en: 'Limited');
  String get measurementConfidenceUnknown =>
      pick(tr: 'Belirsiz', en: 'Unknown');
  String measurementConfidenceValue(String value, String status) => pick(
    tr: 'Ölçüm güveni: $value · $status',
    en: 'Measurement confidence: $value · $status',
  );
  String get descentAscent => pick(tr: 'İniş / Çıkış', en: 'Descent / Ascent');
  String get tempoMeasurementUnavailable => pick(
    tr: 'Tempo ölçümü güvenilir biçimde değerlendirilemedi ve skora dahil edilmedi',
    en: 'Tempo could not be evaluated reliably and was not included in the score',
  );
  String repNumber(int index) => pick(tr: 'Tekrar $index', en: 'Rep $index');
  String attemptNumber(int index) =>
      pick(tr: 'Deneme $index', en: 'Attempt $index');
  String primaryIssue(String issue) =>
      pick(tr: 'Birincil sorun: $issue', en: 'Primary issue: $issue');
  String feedbackLabel(String feedback) =>
      pick(tr: 'Geri bildirim: $feedback', en: 'Feedback: $feedback');
  String get valid => pick(tr: 'Geçerli', en: 'Valid');
  String get lowConfidence => pick(tr: 'Düşük Güven', en: 'Low Confidence');
  String get invalid => pick(tr: 'Geçersiz', en: 'Invalid');
  String get uncertain => pick(tr: 'Belirsiz', en: 'Unknown');
  String get rangeRep => pick(tr: 'Tekrar Analizi', en: 'Range Rep');
  String get left => pick(tr: 'Sol', en: 'Left');
  String get right => pick(tr: 'Sağ', en: 'Right');
  String get insufficientRangeOfMotion =>
      pick(tr: 'Yetersiz hareket açıklığı', en: 'Insufficient range of motion');
  String get excessiveDescentSpeed =>
      pick(tr: 'İniş çok hızlı', en: 'Descent too fast');
  String get excessiveAscentSpeed =>
      pick(tr: 'Çıkış çok hızlı', en: 'Ascent too fast');
  String get persistentFormBreak =>
      pick(tr: 'Kalıcı form bozulması', en: 'Persistent form break');
  String get coverageLoss =>
      pick(tr: 'Görünürlük kaybı', en: 'Visibility loss');
  String get sideSwitchDuringRep =>
      pick(tr: 'Tekrar içinde taraf değişimi', en: 'Side switch during rep');
  String get incompletePhase =>
      pick(tr: 'Eksik faz tamamlanması', en: 'Incomplete phase');
  String get bestScore => pick(tr: 'En İyi Skor', en: 'Best Score');
  String get bestFormRangeScore => pick(
    tr: 'En İyi Form ve Hareket Aralığı Skoru',
    en: 'Best Form and Range Score',
  );
  String get lowestScore => pick(tr: 'En Düşük Skor', en: 'Lowest Score');
  String get lowestFormRangeScore => pick(
    tr: 'En Düşük Form ve Hareket Aralığı Skoru',
    en: 'Lowest Form and Range Score',
  );
  String get validReps => pick(tr: 'Geçerli', en: 'Valid');
  String get invalidReps => pick(tr: 'Geçersiz', en: 'Invalid');
  String get formWarnings => pick(tr: 'Form Uyarısı', en: 'Form Warnings');
  String get formViolations => pick(tr: 'Form İhlali', en: 'Form Violations');
  String get visibilityLoss =>
      pick(tr: 'Görünürlük Kaybı', en: 'Visibility Loss');
  String get sideChanges => pick(tr: 'Taraf Değişimi', en: 'Side Changes');

  // Score trend
  String formScoreTrend(String exerciseName) => pick(
    tr: '$exerciseName Form Skoru Trendi',
    en: '$exerciseName Form Score Trend',
  );
  String get viewDetails => pick(tr: 'Detayı Gör', en: 'View Details');
  String get scoreTrendRangeTitle =>
      pick(tr: 'Zaman Aralığı', en: 'Time Range');
  String get scoreTrendLastSevenDays => pick(tr: '7 Gün', en: '7 Days');
  String get scoreTrendLastThirtyDays => pick(tr: '30 Gün', en: '30 Days');
  String get scoreTrendAllTime => pick(tr: 'Tümü', en: 'All Time');
  String get scoreTrendLastSevenDaysContext =>
      pick(tr: 'son 7 gün', en: 'the last 7 days');
  String get scoreTrendLastThirtyDaysContext =>
      pick(tr: 'son 30 gün', en: 'the last 30 days');
  String get scoreTrendAllTimeContext =>
      pick(tr: 'tüm zamanlar', en: 'the full history');
  String formScoreTrendRangeSubtitle(
    String exerciseName,
    String rangeContext,
  ) => pick(
    tr: '$exerciseName için $rangeContext boyunca form skoru değişimi.',
    en: 'Form score change for $exerciseName across $rangeContext.',
  );
  String formScoreTrendRangeEmpty(String exerciseName, String rangeContext) =>
      pick(
        tr: '$exerciseName için $rangeContext içinde form skoru yok.',
        en: 'There is no form score for $exerciseName in $rangeContext.',
      );
  String get formScoreTrendRangeEmptyDetail => pick(
    tr: 'Başka bir zaman aralığı seçebilir veya yeni bir analiz tamamlayabilirsin.',
    en: 'Choose another time range or complete a new analysis.',
  );
  String formScoreChangeSubtitle(String exerciseName) => pick(
    tr: '$exerciseName oturumlarındaki form skoru değişimi',
    en: 'Form score change across $exerciseName sessions',
  );
  String get noFormScoreToChart => pick(
    tr: 'Henüz çizilecek form skoru yok.',
    en: 'There is no form score to chart yet.',
  );
  String get formScoreDataUnavailable => pick(
    tr: 'Form skoru verisi alınamadı.',
    en: 'Form score data could not be loaded.',
  );
  String get tryAgainLater => pick(
    tr: 'Biraz sonra tekrar deneyebilirsin.',
    en: 'Try again in a moment.',
  );
  String formScoreTrendUnavailable(String exerciseName) => pick(
    tr: '$exerciseName form skoru trendi hazırlanamadı.',
    en: 'The form score trend for $exerciseName could not be prepared.',
  );
  String formScoreTrendEmpty(String exerciseName) => pick(
    tr: '$exerciseName için henüz form skoru trendi yok.',
    en: 'There is no form score trend for $exerciseName yet.',
  );
  String get formScoreTrendEmptyDetail => pick(
    tr: 'Bu egzersizde form skoru üreten analizler tamamlandığında değişim burada görünür.',
    en: 'The trend will appear here after analyses that produce a form score are completed for this exercise.',
  );
  String formScoreTrendChronological(String exerciseName) => pick(
    tr: '$exerciseName oturumlarının tarih sırasına göre form skoru değişimi.',
    en: 'Form score change across $exerciseName sessions in chronological order.',
  );
  String get session => pick(tr: 'Oturum', en: 'Sessions');
  String get latestFormScore =>
      pick(tr: 'Son Form Skoru', en: 'Latest Form Score');
  String get bestFormScore =>
      pick(tr: 'En İyi Form Skoru', en: 'Best Form Score');

  // Planned workout
  String get plannedWorkoutIntro => pick(
    tr: 'Hareketleri seç. Her dinamik hareket 10 tekrar, hold hareketi 30 saniye olarak başlar. Set tamamlanınca sonraki adıma sen geçersin.',
    en: 'Choose your exercises. Each dynamic exercise starts at 10 reps and each hold exercise at 30 seconds. You advance to the next step after completing a set.',
  );
  String get plannedWorkoutBuilderIntro => pick(
    tr: 'Hareketleri istediğin sırada ekle; set, hedef ve dinlenme sürelerini düzenle. Aynı hareketi plana birden fazla kez ekleyebilirsin.',
    en: 'Add exercises in the order you want, then edit sets, targets, and rest. The same exercise can appear more than once.',
  );
  String get planName => pick(tr: 'Plan adı', en: 'Plan name');
  String get planNameHint =>
      pick(tr: 'Örn. Evde üst vücut', en: 'e.g. Upper body at home');
  String get savedPlans => pick(tr: 'Kayıtlı planlar', en: 'Saved plans');
  String get newPlan => pick(tr: 'Yeni plan', en: 'New plan');
  String get noSavedPlans =>
      pick(tr: 'Henüz kayıtlı plan yok.', en: 'No saved plans yet.');
  String get savedPlansLoadFailed => pick(
    tr: 'Kayıtlı planlar yüklenemedi.',
    en: 'Saved plans could not be loaded.',
  );
  String savedPlanSummary({required int exercises, required int sets}) => pick(
    tr: '$exercises adım • $sets set',
    en: '$exercises steps • $sets sets',
  );
  String get deletePlan => pick(tr: 'Planı sil', en: 'Delete plan');
  String deletePlanConfirmation(String name) => pick(
    tr: '“$name” planı kalıcı olarak silinsin mi?',
    en: 'Permanently delete the “$name” plan?',
  );
  String get planSaved => pick(tr: 'Plan kaydedildi.', en: 'Plan saved.');
  String get savePlanChanges =>
      pick(tr: 'Değişiklikleri Kaydet', en: 'Save Changes');
  String get unsavedPlanChanges => pick(
    tr: 'Kaydedilmemiş değişiklikler var.',
    en: 'There are unsaved changes.',
  );
  String get planUpToDate =>
      pick(tr: 'Plan güncel.', en: 'Plan is up to date.');
  String get discardPlanChangesTitle =>
      pick(tr: 'Değişiklikler silinsin mi?', en: 'Discard changes?');
  String get discardPlanChangesBody => pick(
    tr: 'Kaydetmediğin plan değişiklikleri kaybolacak.',
    en: 'Your unsaved plan changes will be lost.',
  );
  String get discardChanges =>
      pick(tr: 'Değişiklikleri Sil', en: 'Discard Changes');
  String get planSaveFailed => pick(
    tr: 'Plan kaydedilemedi. Tekrar dene.',
    en: 'The plan could not be saved. Try again.',
  );
  String get exerciseOrder => pick(tr: 'Hareket sırası', en: 'Exercise order');
  String get addExercise => pick(tr: 'Hareket ekle', en: 'Add exercise');
  String get emptyPlanTitle =>
      pick(tr: 'Plan henüz boş', en: 'Your plan is empty');
  String get emptyPlanBody => pick(
    tr: 'İlk hareketi ekleyerek sıralamayı oluşturmaya başla.',
    en: 'Add the first exercise to start building the order.',
  );
  String get duplicateExercise =>
      pick(tr: 'Hareketi çoğalt', en: 'Duplicate exercise');
  String get removeExercise =>
      pick(tr: 'Hareketi kaldır', en: 'Remove exercise');
  String get setCount => pick(tr: 'Set', en: 'Sets');
  String get repTarget => pick(tr: 'Tekrar hedefi', en: 'Rep target');
  String get holdTarget => pick(tr: 'Tutuş hedefi', en: 'Hold target');
  String get restDuration => pick(tr: 'Dinlenme', en: 'Rest');
  String get secondsShort => pick(tr: 'sn', en: 'sec');
  String get repetitionsShort => pick(tr: 'tekrar', en: 'reps');
  String get savePlan => pick(tr: 'Planı Kaydet', en: 'Save Plan');
  String get reviewPlan => pick(tr: 'Özeti Gör', en: 'Review Plan');
  String get defaultRepTarget => pick(
    tr: 'Varsayılan: 10 tekrar • 15 sn dinlenme',
    en: 'Default: 10 reps • 15 sec rest',
  );
  String get defaultHoldTarget => pick(
    tr: 'Varsayılan: 30 saniye • 15 sn dinlenme',
    en: 'Default: 30 seconds • 15 sec rest',
  );
  String get planSummary => pick(tr: 'Plan Özeti', en: 'Plan Summary');
  String get exerciseEntries => pick(tr: 'Hareket adımı', en: 'Exercise steps');
  String get totalPlannedSets =>
      pick(tr: 'Toplam planlanan set', en: 'Total planned sets');
  String get estimatedRest =>
      pick(tr: 'Tahmini dinlenme', en: 'Estimated rest');
  String get editPlan => pick(tr: 'Düzenle', en: 'Edit');
  String get startPlan => pick(tr: 'Planı Başlat', en: 'Start Plan');
  String get saveAndStartPlan =>
      pick(tr: 'Kaydet ve Başlat', en: 'Save and Start');
  String repTargetSummary(int repetitions) =>
      pick(tr: '$repetitions tekrar', en: '$repetitions reps');
  String holdTargetSummary(int seconds) =>
      pick(tr: '$seconds saniye tutuş', en: '$seconds-second hold');
  String planEntrySummary({
    required int sets,
    required String target,
    required int restSeconds,
  }) => pick(
    tr: '$sets set • $target • set sonrası $restSeconds sn dinlenme',
    en: '$sets sets • $target • $restSeconds sec rest after each set',
  );
  String restCountdown(String duration) =>
      pick(tr: 'Dinlenme: $duration', en: 'Rest: $duration');
  String get restScreenTitle => pick(tr: 'Dinlenme', en: 'Rest');
  String get restSetCompleted =>
      pick(tr: 'Set tamamlandı', en: 'Set completed');
  String get plannedExerciseCompleted =>
      pick(tr: 'Egzersiz tamamlandı', en: 'Exercise completed');
  String plannedExerciseCompletedMessage(String exerciseName) => pick(
    tr: '$exerciseName tamamlandı. Kısa bir dinlenme başlıyor.',
    en: '$exerciseName is complete. A short rest is starting.',
  );
  String nextPlannedStep(String exerciseName, int setNumber) => pick(
    tr: 'Sırada: $exerciseName • Set $setNumber',
    en: 'Next: $exerciseName • Set $setNumber',
  );
  String get restTipTitle => pick(tr: 'Kısa mola', en: 'Quick reset');
  String get restTipBody => pick(
    tr: 'Nefesini düzenle, bir yudum su al ve sıradaki başlangıç pozisyonuna hazırlan.',
    en: 'Settle your breathing, take a sip of water, and prepare for the next starting position.',
  );
  String get nextSetStarting =>
      pick(tr: 'Yeni set başlıyor', en: 'Next set starting');
  String get restReadyTitle => pick(tr: 'Hazırsın', en: 'You’re Ready');
  String get restReadyMessage => pick(
    tr: 'Hazır olduğunda sıradaki sete geç.',
    en: 'Continue to the next set when you are ready.',
  );
  String get readyForNextSet => pick(tr: 'Hazırım', en: 'I’m Ready');
  String addRestTime(int seconds) =>
      pick(tr: '+$seconds sn', en: '+$seconds sec');
  String get skipRest => pick(tr: 'Dinlenmeyi Atla', en: 'Skip Rest');
  String get roundCount => pick(tr: 'Tur sayısı', en: 'Number of rounds');
  String get selectAtLeastOneExercise =>
      pick(tr: 'En az bir hareket seç', en: 'Select at least one exercise');
  String startWithExerciseCount(int count) => pick(
    tr: '$count hareketle başla',
    en: 'Start with $count ${count == 1 ? 'exercise' : 'exercises'}',
  );
  String get thirtySecondHold =>
      pick(tr: '30 saniye tutuş', en: '30-second hold');
  String get tenReps => pick(tr: '10 tekrar', en: '10 reps');
  String targetSetLabel(String target) =>
      pick(tr: '1 set • $target', en: '1 set • $target');
  String get workoutSummary =>
      pick(tr: 'Antrenman Özeti', en: 'Workout Summary');
  String get noCompletedPlan => pick(
    tr: 'Tamamlanmış bir plan bulunamadı.',
    en: 'No completed workout plan was found.',
  );
  String get planCompleted => pick(tr: 'Plan tamamlandı', en: 'Plan completed');
  String get completedSets => pick(tr: 'Tamamlanan set', en: 'Completed sets');
  String get totalDuration => pick(tr: 'Toplam süre', en: 'Total duration');
  String get returnHome => pick(tr: 'Ana Sayfaya Dön', en: 'Return Home');
  String workoutAggregateSummary({
    required int sets,
    required int reps,
    required String holdDuration,
  }) => pick(
    tr: '$sets set • $reps tekrar • $holdDuration tutuş',
    en: '$sets sets • $reps reps • $holdDuration hold',
  );

  // Workout summary / live analysis chrome
  String get sessionDataMissing =>
      pick(tr: 'Oturum verisi bulunamadı', en: 'Session data not found');
  String get sessionDataMissingDetail =>
      pick(tr: 'Oturum verisi bulunamadı.', en: 'Session data was not found.');
  String exerciseSummary(String exerciseName) =>
      pick(tr: '$exerciseName özeti', en: '$exerciseName summary');
  String get summaryAppearsAfterAnalysis => pick(
    tr: 'Canlı analiz tamamlandığında oturum özeti burada görünür.',
    en: 'The session summary will appear here after live analysis is completed.',
  );
  String get summaryUsesRecordedValues => pick(
    tr: 'Canlı analizden oluşturulan gerçek oturum değerleri.',
    en: 'Recorded session values generated by live analysis.',
  );
  String get summaryResultExcellent =>
      pick(tr: 'Çok güçlü sonuç', en: 'Excellent result');
  String get summaryResultStrong =>
      pick(tr: 'Güçlü sonuç', en: 'Strong result');
  String get summaryResultSteady =>
      pick(tr: 'Dengeli sonuç', en: 'Steady result');
  String get summaryResultNeedsFocus =>
      pick(tr: 'Geliştirilebilir sonuç', en: 'Result needs focus');
  String get summaryResultCompleted =>
      pick(tr: 'Oturum tamamlandı', en: 'Session completed');
  String get summaryHighlight =>
      pick(tr: 'Öne çıkan sonuç', en: 'Session highlight');
  String get summaryNextFocus => pick(tr: 'Sonraki odak', en: 'Next focus');
  String get summaryMaintainControl => pick(
    tr: 'Aynı kontrollü formu koruyarak ilerlemeye devam et.',
    en: 'Keep progressing while maintaining the same controlled form.',
  );
  String summaryBestScoreHighlight(String score) => pick(
    tr: 'En iyi tekrarın $score form ve hareket aralığı skoruna ulaştı.',
    en: 'Your best repetition reached a form and range score of $score.',
  );
  String summaryBestHoldHighlight(String duration) => pick(
    tr: 'En iyi kesintisiz tutuşun $duration sürdü.',
    en: 'Your best uninterrupted hold lasted $duration.',
  );
  String summaryRepHighlight(int reps) => pick(
    tr: '$reps tekrar tamamlandı.',
    en: '$reps ${reps == 1 ? 'repetition was' : 'repetitions were'} completed.',
  );
  String get preparing => pick(tr: 'Hazırlanıyor...', en: 'Preparing...');
  String get exerciseType => pick(tr: 'Egzersiz tipi', en: 'Exercise type');
  String get formBreaks => pick(tr: 'Form kesintisi', en: 'Form breaks');
  String get validRep => pick(tr: 'Geçerli tekrar', en: 'Valid reps');
  String get invalidRep => pick(tr: 'Geçersiz tekrar', en: 'Invalid reps');
  String get formWarning => pick(tr: 'Form uyarısı', en: 'Form warnings');
  String get workoutSummaryTotalHold =>
      pick(tr: 'Toplam tutuş', en: 'Total hold');
  String get workoutSummaryBestHold =>
      pick(tr: 'En iyi tutuş', en: 'Best hold');
  String get workoutSummaryFormBreaks =>
      pick(tr: 'Form kesintisi', en: 'Form breaks');
  String get workoutSummaryTotalReps =>
      pick(tr: 'Toplam tekrar', en: 'Total reps');
  String get workoutSummaryAverageScore =>
      pick(tr: 'Ortalama skor', en: 'Average score');
  String get workoutSummaryAverageFormRangeScore => pick(
    tr: 'Ortalama form ve hareket aralığı skoru',
    en: 'Average form and range score',
  );
  String get workoutSummaryBestScore =>
      pick(tr: 'En iyi skor', en: 'Best score');
  String get workoutSummaryBestFormRangeScore => pick(
    tr: 'En iyi form ve hareket aralığı skoru',
    en: 'Best form and range score',
  );
  String get workoutSummaryValidReps =>
      pick(tr: 'Geçerli tekrar', en: 'Valid reps');
  String get workoutSummaryInvalidReps =>
      pick(tr: 'Geçersiz deneme', en: 'Rejected attempts');
  String get averageRom => pick(tr: 'Ortalama ROM', en: 'Average ROM');
  String get averageTempo => pick(tr: 'Ortalama tempo', en: 'Average tempo');
  String get fastestRep => pick(tr: 'En hızlı tekrar', en: 'Fastest rep');
  String get slowestRep => pick(tr: 'En yavaş tekrar', en: 'Slowest rep');
  String get tempoConsistency =>
      pick(tr: 'Tempo tutarlılığı', en: 'Tempo consistency');
  String get leftReps => pick(tr: 'Sol tekrar', en: 'Left reps');
  String get rightReps => pick(tr: 'Sağ tekrar', en: 'Right reps');
  String get averageRomDifference =>
      pick(tr: 'Ortalama ROM farkı', en: 'Average ROM difference');
  String get asymmetryScore =>
      pick(tr: 'Asimetri skoru', en: 'Asymmetry score');
  String get finish => pick(tr: 'Bitir', en: 'Finish');
  String get endWorkout => pick(tr: 'Antrenmanı Bitir', en: 'End Workout');
  String get liveExitDialogTitle => pick(
    tr: 'Antrenmanı bitirmek istiyor musun?',
    en: 'Do you want to end the workout?',
  );
  String get liveExitDialogMessage => pick(
    tr: 'Bu oturumda kaydedilebilir ilerleme var. Antrenmana dönebilir, sonucu kaydedebilir veya kaydetmeden çıkabilirsin.',
    en: 'This session has progress that can be saved. You can return to the workout, save the result, or exit without saving.',
  );
  String get returnToWorkout =>
      pick(tr: 'Antrenmana Dön', en: 'Return to Workout');
  String get saveAndFinish =>
      pick(tr: 'Kaydet ve Bitir', en: 'Save and Finish');
  String get exitWithoutSaving =>
      pick(tr: 'Kaydetmeden Çık', en: 'Exit Without Saving');
  String get continueLabel => pick(tr: 'Devam', en: 'Continue');
  String get holdMetric => pick(tr: 'TUTUŞ', en: 'HOLD');
  String get repMetric => pick(tr: 'TEKRAR', en: 'REPS');
  String get bestMetric => pick(tr: 'EN İYİ', en: 'BEST');
  String get scoreMetric => pick(tr: 'SKOR', en: 'SCORE');
  String get formRangeScoreMetric => pick(tr: 'FORM/ROM', en: 'FORM/ROM');
  String get angleMetric => pick(tr: 'AÇI', en: 'ANGLE');
  String get tempoMetric => 'TEMPO';
  String get stabilityMetric => pick(tr: 'STABİLİTE', en: 'STABILITY');
  String get asymmetryMetric => pick(tr: 'ASİMETRİ', en: 'ASYMMETRY');
  String get phaseMetric => pick(tr: 'FAZ', en: 'PHASE');
  String get rangeOfMotionMetric =>
      pick(tr: 'HAREKET AÇIKLIĞI', en: 'RANGE OF MOTION');
  String get liveHudShowDetails =>
      pick(tr: 'Ayrıntıları göster', en: 'Show details');
  String get liveHudUseMinimalView =>
      pick(tr: 'Minimal görünüme dön', en: 'Use minimal view');
  String get liveHudTechnicalDetails =>
      pick(tr: 'Canlı analiz ayrıntıları', en: 'Live analysis details');
  String get liveHudPlanProgress =>
      pick(tr: 'PLAN İLERLEMESİ', en: 'PLAN PROGRESS');
  String get automaticLegSelectionPrompt => pick(
    tr: 'Bir bacağını hareket ettir; takip edilen taraf otomatik seçilecek.',
    en: 'Move either leg; the tracked side will be selected automatically.',
  );
  String trackedLeg(String side) {
    return switch (side.toLowerCase()) {
      'left' => pick(tr: 'Sol bacak takip ediliyor', en: 'Tracking left leg'),
      'right' => pick(tr: 'Sağ bacak takip ediliyor', en: 'Tracking right leg'),
      _ => pick(tr: 'Bacak takip ediliyor', en: 'Tracking leg'),
    };
  }

  String workoutPhaseLabel(String phase) {
    return switch (phase.toUpperCase()) {
      'AWAITING_NEUTRAL' => pick(
        tr: 'Başlangıç bekleniyor',
        en: 'Awaiting start',
      ),
      'WAITING' => pick(tr: 'Bekleniyor', en: 'Waiting'),
      'NEUTRAL' || 'READY' => pick(tr: 'Hazır', en: 'Ready'),
      'DESCENDING' => pick(tr: 'Hareket', en: 'Movement'),
      'PEAK' => pick(tr: 'Geçiş', en: 'Transition'),
      'ASCENDING' => pick(tr: 'Dönüş', en: 'Return'),
      'HOLDING' => pick(tr: 'Tutuş', en: 'Holding'),
      'BROKEN' => pick(tr: 'Pozisyon bozuldu', en: 'Position broken'),
      _ => phase,
    };
  }

  String plannedWorkoutProgress({
    required int round,
    required int totalRounds,
    required int set,
    required int totalSets,
  }) => pick(
    tr: 'Tur $round/$totalRounds • Set $set/$totalSets',
    en: 'Round $round/$totalRounds • Set $set/$totalSets',
  );
  String repetitionProgress(int current, int target) =>
      pick(tr: '$current / $target tekrar', en: '$current / $target reps');
  String get finalSetCompleted =>
      pick(tr: 'Son set tamamlandı.', en: 'Final set completed.');
  String get setCompletedContinue => pick(
    tr: 'Set tamamlandı. Hazır olduğunda devam et.',
    en: 'Set completed. Continue when you are ready.',
  );
  String get liveAnalysisSelectionTitle => pick(
    tr: 'Canlı analize girmek için hareket seç',
    en: 'Choose an exercise to enter live analysis',
  );
  String get liveAnalysisSelectionMessage => pick(
    tr: 'Canlı analiz ekranı yalnızca geçerli bir hareket seçiminden sonra açılabilir.',
    en: 'The live analysis screen can only be opened after a valid exercise is selected.',
  );
  String get cameraRecovering => pick(
    tr: 'Kamera yeniden hazırlanıyor...',
    en: 'Preparing the camera again...',
  );
  String get cameraPermissionFallbackBody => pick(
    tr: 'Analize devam etmek için kamera iznini kontrol et.',
    en: 'Check camera permission to continue the analysis.',
  );
  String get liveTrackingTemporarilyLostTitle =>
      pick(tr: 'Görüntü kısa süreli kayboldu', en: 'Tracking was briefly lost');
  String get liveTrackingTemporarilyLostMessage => pick(
    tr: 'Pozisyonunu koru. Analiz kısa süreli olarak bekletiliyor.',
    en: 'Hold your position. Analysis is paused briefly.',
  );
  String get liveTrackingRepositionTitle =>
      pick(tr: 'Kadraja geri dön', en: 'Move back into frame');
  String get liveTrackingRepositionMessage => pick(
    tr: 'Vücudunu tekrar kameraya göster. Sayım ve süre güvenli biçimde duraklatıldı.',
    en: 'Show your body to the camera again. Counting and timing are safely paused.',
  );
  String get liveTrackingReacquiringTitle =>
      pick(tr: 'Pozisyon kontrol ediliyor', en: 'Checking your position');
  String get liveTrackingReacquiringMessage => pick(
    tr: 'Kısa süre sabit kal. Analiz güvenli olduğunda devam edecek.',
    en: 'Hold still briefly. Analysis will resume when tracking is stable.',
  );
  String get pauseWorkout => pick(tr: 'Duraklat', en: 'Pause');
  String get resumeWorkout => pick(tr: 'Devam Et', en: 'Resume');
  String get returnToPause =>
      pick(tr: 'Duraklamaya Dön', en: 'Return to Pause');
  String get workoutPausedTitle =>
      pick(tr: 'Antrenman duraklatıldı', en: 'Workout paused');
  String get workoutPausedMessage => pick(
    tr: 'Su içebilir, telefonu düzeltebilir veya pozisyonunu değiştirebilirsin. Hazır olduğunda devam et.',
    en: 'Take a drink, adjust the phone, or change position. Resume when you are ready.',
  );
  String get resumeReadinessTitle =>
      pick(tr: 'Devam etmeye hazırlan', en: 'Prepare to resume');
  String get resumeCountdownTitle =>
      pick(tr: 'Analiz devam ediyor', en: 'Analysis is resuming');
  String get resumeCountdownMessage => pick(
    tr: 'Pozisyonunu koru. Sayım geri sayım tamamlanınca devam edecek.',
    en: 'Hold your position. Counting resumes when the countdown finishes.',
  );
  String liveResumeCountdownSemantics(int value) => pick(
    tr: 'Analize devam etmek için $value',
    en: '$value until analysis resumes',
  );
  String get checkPermission =>
      pick(tr: 'İzni Kontrol Et', en: 'Check Permission');
  // Runtime coaching / voice
  String get ttsLanguageTag => isTurkish ? 'tr-TR' : 'en-US';

  // Live assessment runtime
  String get assessmentFrameAnalysisFailed => pick(
    tr: 'Kare analiz edilemedi. Pozisyonunu koru.',
    en: 'The frame could not be analyzed. Hold your position.',
  );
  String get assessmentHoldPositionBriefly => pick(
    tr: 'Pozisyonunu kısa süre sabit tut.',
    en: 'Hold your position steady for a moment.',
  );
  String get assessmentNotReadyFeedback => pick(
    tr: 'Ölçüm henüz hazır değil. Yönergeyi tamamlamaya devam et.',
    en: 'The measurement is not ready yet. Keep following the instruction.',
  );
  String get assessmentCompletedFeedback => pick(
    tr: 'Kamera ölçümü tamamlandı.',
    en: 'Camera measurement completed.',
  );
  String get assessmentInsufficientFeedback => pick(
    tr: 'Sonuç için yeterli ölçüm toplanamadı.',
    en: 'Not enough measurement data was collected for a result.',
  );
  String get assessmentReadyFeedback => pick(
    tr: 'Ölçüm hazır. Sonucu görmek için aşağıdaki düğmeye dokun.',
    en: 'The measurement is ready. Tap the button below to view the result.',
  );
  String get balanceStanceResetFeedback => pick(
    tr: 'Tek ayak duruşu bozuldu. Süre yeniden başladı.',
    en: 'The single-leg stance was interrupted. The timer restarted.',
  );
  String get assessmentReady =>
      pick(tr: 'Ölçüm hazır', en: 'Measurement ready');
  String assessmentMovementProgress(int percent) => pick(
    tr: 'Hareket ilerlemesi: %$percent',
    en: 'Movement progress: $percent%',
  );
  String assessmentContinuousStanceProgress(String elapsed, String target) =>
      pick(
        tr: 'Kesintisiz duruş: $elapsed / $target sn',
        en: 'Continuous stance: $elapsed / $target s',
      );
  String assessmentElevationProgress(int percent) => pick(
    tr: 'Kol kaldırma ilerlemesi: %$percent',
    en: 'Arm raise progress: $percent%',
  );
  String get squatAssessmentInstruction => pick(
    tr: 'Kameraya sol veya sağ yanını dön. Tüm vücudun kadrajdayken kontrollü bir squat yap ve tekrar ayağa kalk.',
    en: 'Turn your left or right side toward the camera. Keep your whole body in frame, perform one controlled squat, then stand back up.',
  );
  String get balanceAssessmentInstruction => pick(
    tr: 'Kameraya önden dön. Tüm vücudun kadrajdayken seçilen ayağın üzerinde kesintisiz sabit kal.',
    en: 'Face the camera. Keep your whole body in frame and remain steadily on the selected foot without interruption.',
  );
  String get shoulderAssessmentInstruction => pick(
    tr: 'Kameraya önden dön. Dirseklerini mümkün olduğunca düz tutarak kollarını gövdenin yanından iki yana doğru kontrollü biçimde kaldır.',
    en: 'Face the camera. Keep your elbows as straight as possible and raise both arms out to the sides with control.',
  );
  String get poseQualityLowConfidence => pick(
    tr: 'Görüntü yeterince net değil. Işığı artır ve tüm vücudunu görünür tut.',
    en: 'The image is not clear enough. Improve the lighting and keep your whole body visible.',
  );
  String get poseQualityGeometryUnavailable => pick(
    tr: 'Pozisyon ölçülemiyor. Kameradan biraz uzaklaşıp tüm vücudunu kadraja al.',
    en: 'Your position cannot be measured. Move slightly farther from the camera and keep your whole body in frame.',
  );
  String get poseQualityKeepRequiredJointsVisible => pick(
    tr: 'Tüm vücudunu kadraja al ve gerekli eklemleri görünür tut.',
    en: 'Keep your whole body in frame and make sure the required joints are visible.',
  );

  // Runtime errors / retry / persistence
  String get analysisSessionPreparationFailed => pick(
    tr: 'Analiz oturumu hazırlanamadı. Bağlantını kontrol edip tekrar dene.',
    en: 'The analysis session could not be prepared. Check your connection and try again.',
  );
  String get selectValidExerciseBeforeAnalysis => pick(
    tr: 'Analiz için önce geçerli bir hareket seçmelisin.',
    en: 'Choose a valid exercise before starting the analysis.',
  );
  String get sessionSaveFailed => pick(
    tr: 'Oturum kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
    en: 'The session could not be saved. Check your connection and try again.',
  );
  String get plannedStepMissingUser => pick(
    tr: 'Antrenman adımı kaydedilemedi: kullanıcı bulunamadı.',
    en: 'The workout step could not be saved: user not found.',
  );
  String get plannedStepMissingExercise => pick(
    tr: 'Aktif antrenman hareketi bulunamadı.',
    en: 'The active workout exercise could not be found.',
  );
  String get plannedStepSaveFailed => pick(
    tr: 'Antrenman adımı kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
    en: 'The workout step could not be saved. Check your connection and try again.',
  );
  String get cameraPermissionAnalysisRequired => pick(
    tr: 'Kamera izni olmadan analiz başlatılamaz.',
    en: 'Analysis cannot start without camera permission.',
  );

  // Demo coach runtime
  String get coachWelcomeMessage => pick(
    tr: 'Merhaba, ben AI Coach. Form, squat tekniği veya antrenman planı hakkında kısa öneriler verebilirim.',
    en: 'Hi, I am AI Coach. I can give short suggestions about form, squat technique, or workout planning.',
  );
  String get coachPersonalizationHint => pick(
    tr: 'Canlı analiz verilerin geliştikçe burada daha kişisel öneriler görebileceksin.',
    en: 'As your live analysis data grows, you will see more personalized suggestions here.',
  );
  String get coachSquatReply => pick(
    tr: 'Squat için dizlerini ayak parmaklarınla aynı hatta tutmaya ve inişi kontrollü yapmaya odaklan.',
    en: 'For squats, keep your knees tracking in line with your toes and focus on a controlled descent.',
  );
  String get coachFormReply => pick(
    tr: 'Formu düzeltmek için tekrar hızını biraz düşür, gövdeni sabit tut ve hareket aralığını koru.',
    en: 'To improve your form, slow the rep slightly, keep your torso stable, and maintain your range of motion.',
  );
  String get coachPlanReply => pick(
    tr: 'Bugün kısa bir plan iyi olabilir: ısınma, 3 kontrollü set ve set aralarında yeterli dinlenme.',
    en: 'A short plan could work well today: warm up, complete 3 controlled sets, and rest enough between sets.',
  );
  String get coachDefaultReply => pick(
    tr: 'İyi gidiyorsun. Kısa, kontrollü setlerle form kalitesini korumaya devam et.',
    en: 'You are doing well. Keep protecting your form quality with short, controlled sets.',
  );

  // Localized session report copy
  String get sessionReportSummaryOnly => pick(
    tr: 'Bu oturumda tekrar detayları yok; yalnızca özet verileri gösteriliyor.',
    en: 'Rep details are unavailable for this session; only summary data is shown.',
  );
  String get sessionReportNoCompletedReps => pick(
    tr: 'Bu oturumda tamamlanmış tekrar kaydı yok.',
    en: 'No completed reps were recorded in this session.',
  );
  String sessionReportRangeSummary({
    required int totalReps,
    required int validReps,
    required int lowConfidenceReps,
    required int invalidReps,
    required int unknownReps,
    required double averageScore,
    String? topIssue,
  }) {
    if (isTurkish) {
      final parts = <String>[
        '$totalReps tekrar sayıldı: $validReps tanesi geçerli',
      ];
      if (lowConfidenceReps > 0) {
        parts.add('$lowConfidenceReps tanesi düşük güvenli');
      }
      if (unknownReps > 0) {
        parts.add('$unknownReps tanesi belirsiz');
      }
      if (invalidReps > 0) {
        parts.add('$invalidReps geçersiz deneme sayaca eklenmedi');
      }
      final summary = '${parts.join(', ')}.';
      if (topIssue != null && topIssue.isNotEmpty) {
        return '$summary En sık sorun: $topIssue.';
      }
      if (averageScore > 0) {
        return '$summary Ortalama skor ${averageScore.toStringAsFixed(0)}.';
      }
      return summary;
    }

    final parts = <String>['$totalReps reps counted: $validReps were valid'];
    if (lowConfidenceReps > 0) {
      parts.add('$lowConfidenceReps were low-confidence');
    }
    if (unknownReps > 0) {
      parts.add('$unknownReps were uncertain');
    }
    if (invalidReps > 0) {
      parts.add('$invalidReps invalid attempts were excluded from the count');
    }
    final summary = '${parts.join(', ')}.';
    if (topIssue != null && topIssue.isNotEmpty) {
      return '$summary Most common issue: $topIssue.';
    }
    if (averageScore > 0) {
      return '$summary Average score ${averageScore.toStringAsFixed(0)}.';
    }
    return summary;
  }

  String get holdSessionNoMeaningfulDuration => pick(
    tr: 'Bu tutuş oturumunda anlamlı tutuş süresi kaydedilmedi.',
    en: 'No meaningful hold duration was recorded in this hold session.',
  );
  String holdSessionSummary({
    required double totalSeconds,
    required double bestSeconds,
  }) => pick(
    tr: 'Toplam ${totalSeconds.toStringAsFixed(0)} sn tutuş kaydedildi. En iyi tek deneme ${bestSeconds.toStringAsFixed(0)} sn.',
    en: 'A total of ${totalSeconds.toStringAsFixed(0)} s of holding was recorded. The best single attempt was ${bestSeconds.toStringAsFixed(0)} s.',
  );

  String localizeReportIssue(String issue) {
    return switch (issue.toLowerCase()) {
      'yetersiz hareket açıklığı' ||
      'insufficient range of motion' => insufficientRangeOfMotion,
      'iniş çok hızlı' ||
      'descent too fast' ||
      'hareketin ilk fazı referanstan hızlı göründü' ||
      'the first movement phase appeared faster than the reference tempo' => pick(
        tr: 'Hareketin ilk fazı referans tempodan hızlı göründü',
        en: 'The first movement phase appeared faster than the reference tempo',
      ),
      'çıkış çok hızlı' ||
      'ascent too fast' ||
      'başlangıç pozisyonuna dönüş referanstan hızlı göründü' ||
      'the return to the starting position appeared faster than the reference tempo' =>
        pick(
          tr: 'Başlangıç pozisyonuna dönüş referans tempodan hızlı göründü',
          en: 'The return to the starting position appeared faster than the reference tempo',
        ),
      'toplam hareket referanstan hızlı göründü' ||
      'the total movement appeared faster than the reference tempo' => pick(
        tr: 'Toplam hareket referans tempodan hızlı göründü',
        en: 'The total movement appeared faster than the reference tempo',
      ),
      'kalıcı form bozulması' || 'persistent form break' => persistentFormBreak,
      'görünürlük kaybı' || 'visibility loss' => coverageLoss,
      'tekrar içinde taraf değişimi' ||
      'side switch during rep' => sideSwitchDuringRep,
      'eksik faz tamamlanması' || 'incomplete phase' => incompletePhase,
      _ => issue,
    };
  }

  String localizeReportRecommendation(String recommendation) {
    return switch (recommendation) {
      'Daha derin tekrarlar için hareket açıklığını kontrollü biçimde artır.' =>
        pick(
          tr: 'Daha derin tekrarlar için hareket açıklığını kontrollü biçimde artır.',
          en: 'Increase your range of motion gradually and with control for deeper reps.',
        ),
      'Tekrarları tam iniş ve tam çıkış döngüsüyle tamamlamaya odaklan.' => pick(
        tr: 'Tekrarları tam iniş ve tam çıkış döngüsüyle tamamlamaya odaklan.',
        en: 'Focus on completing each rep through a full descent and ascent cycle.',
      ),
      'Tekrarlar arasında hareket açıklığını, gövde kontrolünü ve ritmi daha tutarlı korumaya çalış.' =>
        pick(
          tr: 'Tekrarlar arasında hareket açıklığını, gövde kontrolünü ve ritmi daha tutarlı korumaya çalış.',
          en: 'Keep range of motion, torso control, and rhythm more consistent across repetitions.',
        ),
      'Tempo ölçümü bazı tekrarlarda referans aralığın dışında göründü; kamerayı sabitleyip ritmi tutarlı koru.' =>
        pick(
          tr: 'Tempo ölçümü bazı tekrarlarda referans aralığın dışında göründü; kamerayı sabitleyip ritmi tutarlı koru.',
          en: 'Tempo appeared outside the reference range on some reps; keep the camera stable and maintain a consistent rhythm.',
        ),
      'Form bozulmasını azaltmak için gövde hizasını ve diz kontrolünü daha sıkı koru.' =>
        pick(
          tr: 'Form bozulmasını azaltmak için gövde hizasını ve diz kontrolünü daha sıkı koru.',
          en: 'Maintain tighter torso alignment and knee control to reduce form breakdowns.',
        ),
      'Kamera açısını sabitle; bazı tekrarlarda görünürlük kaybı oluşmuş.' => pick(
        tr: 'Kamera açısını sabitle; bazı tekrarlarda görünürlük kaybı oluşmuş.',
        en: 'Keep the camera angle fixed; visibility was lost during some reps.',
      ),
      'Set boyunca aynı tarafı daha net gösterecek şekilde pozisyonunu koru.' =>
        pick(
          tr: 'Set boyunca aynı tarafı daha net gösterecek şekilde pozisyonunu koru.',
          en: 'Keep your position consistent so the same side remains clearly visible throughout the set.',
        ),
      'Genel kalite dengeli görünüyor; aynı kontrolü koruyarak tekrar sayısını kademeli artır.' =>
        pick(
          tr: 'Genel kalite dengeli görünüyor; aynı kontrolü koruyarak tekrar sayısını kademeli artır.',
          en: 'Overall quality looks balanced; increase your rep count gradually while maintaining the same control.',
        ),
      'Form uyarıları görüldüğü için sonraki sette hareket çizgisini daha kontrollü koru.' =>
        pick(
          tr: 'Form uyarıları görüldüğü için sonraki sette hareket çizgisini daha kontrollü koru.',
          en: 'Because form warnings were detected, keep the movement path more controlled in the next set.',
        ),
      'Bu rapor özet veriye dayanıyor; benzer bir sonraki sette tekrar detaylarını da incelemek faydalı olur.' =>
        pick(
          tr: 'Bu rapor özet veriye dayanıyor; benzer bir sonraki sette tekrar detaylarını da incelemek faydalı olur.',
          en: 'This report is based on summary data; reviewing rep details in a similar future set may be useful.',
        ),
      'Hold boyunca vücut çizgisini daha sabit tut; form kesintileri görülmüş.' =>
        pick(
          tr: 'Tutuş boyunca vücut çizgisini daha sabit tut; form kesintileri görülmüş.',
          en: 'Keep your body line more stable throughout the hold; form breaks were detected.',
        ),
      'Kısa ama temiz tekrarlarla en iyi hold süresini kademeli artır.' => pick(
        tr: 'Kısa ama temiz denemelerle en iyi tutuş süresini kademeli artır.',
        en: 'Increase your best hold duration gradually with short, clean attempts.',
      ),
      'Süre dengeli görünüyor; aynı hizayı koruyarak toplam tutuş süresini artırabilirsin.' =>
        pick(
          tr: 'Süre dengeli görünüyor; aynı hizayı koruyarak toplam tutuş süresini artırabilirsin.',
          en: 'The duration looks balanced; you can increase total hold time while maintaining the same alignment.',
        ),
      'Önce pozisyonu kilitle, sonra süreyi azar azar uzat.' => pick(
        tr: 'Önce pozisyonu sabitle, sonra süreyi azar azar uzat.',
        en: 'Lock in the position first, then extend the duration gradually.',
      ),
      _ => recommendation,
    };
  }

  String weekdayShort(int weekday) {
    const tr = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    const en = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final index = weekday.clamp(1, 7) - 1;
    return isTurkish ? tr[index] : en[index];
  }
}
