import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Gizlilik Politikasını',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Icon(
              Icons.privacy_tip_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Bu metin, uygulamanın kullanıcı verilerini nasıl ele aldığını açıklar.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 20),
                  Text(
                    'Sign Flow, tamamen cihaz üzerinde çalışan ve hiçbir şekilde sunucuya bağlanmayan bir PDF imzalama uygulamasıdır. Uygulama, kullanıcılarından herhangi bir kişisel veri toplamaz, işlemez, saklamaz veya üçüncü taraflarla paylaşmaz. Kullanıcıların cihazlarında bulunan PDF dosyaları yalnızca lokal olarak açılır, imzalanır ve yine lokal olarak kaydedilir. Dosyaların veya imzaların geliştiriciye ya da herhangi bir kuruluşa iletilmesi mümkün değildir çünkü uygulama internet üzerinden hiçbir veri iletişimi gerçekleştirmez. Uygulama, analitik araçları, çerezler, takip teknolojileri veya reklam amaçlı veri toplama sistemleri kullanmaz. Tüm dosya işlemleri kullanıcı cihazının işletim sistemi tarafından sağlanan güvenlik mekanizmaları kapsamında gerçekleşir. Uygulama içerisinde yapılan imzalama işlemlerine dair hiçbir bilgi kayıt altına alınmaz. Bu gizlilik politikası zamanla güncellenebilir ve güncellemeler yayınlandığı andan itibaren geçerli olur. Sorularınız için info@proaktif01.com adresinden iletişime geçebilirsiniz.',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
