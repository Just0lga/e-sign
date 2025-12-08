import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Hizmet Şartları',
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
              Icons.description_outlined,
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
                    'Bu metin, uygulamanın kullanım koşullarını ve kullanıcı sorumluluklarını açıklar.',
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
                    'Sign Flow, kullanıcıların cihazlarındaki PDF dosyalarını imzalamalarına olanak sağlayan, tamamen lokal çalışan bir mobil uygulamadır. Uygulama herhangi bir sunucu altyapısı kullanmadığından bütün işlemler yalnızca kullanıcının cihazı üzerinde gerçekleşir. İmzalanan belgelerin içeriği, doğruluğu ve saklanması konusunda tüm sorumluluk kullanıcıya aittir; uygulama hukuki geçerlilik, kimlik doğrulama veya elektronik sertifika hizmeti sunmaz. Paylaş özelliği kullanıldığında dosyalar cihazdaki diğer uygulamalara gönderilebilir ve bu paylaşım kullanıcı tarafından başlatıldığı için uygulama bu aşamadan sonraki süreç üzerinde kontrol veya sorumluluk kabul etmez. Uygulama “olduğu gibi” sunulmakta olup geliştirici herhangi bir garanti vermez ve kullanım sırasında oluşabilecek dosya kayıpları, hatalar veya teknik sorunlardan dolayı sorumluluk kabul etmez. Hizmet şartları gerektiğinde güncellenebilir ve güncellemeler yayınlandığı anda geçerlilik kazanır. Her türlü soru için info@proaktif01.com üzerinden bize ulaşabilirsiniz.',
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
