# Sorun Giderme

## "winws.exe bulunamadi" / "WinDivert64.sys bulunamadi"
ZIP dosyasini cikardiginiz klasoru degistirmeyin/tasimayin, `engine\`
klasorunun `ZapretTurkey.bat` ile ayni ust dizinde oldugundan emin olun.

## Baslatinca hemen kapaniyor
- Yonetici olarak calistirdiginizdan emin olun (program bunu kendisi sorar).
- Ayni WinDivert surucusunu kullanan baska bir arac (GoodbyeDPI, eski bir
  Zapret kurulumu, baska bir "DPI bypass" programi) ayni anda calisiyor
  olabilir. Tanilama menusu (secenek 6) bunu kontrol eder.
- `durdur.bat` yerine artik ana menudeki [2] Durdur secenegini kullanin.

## Discord acilmiyor / "update failed" hatasi
- Once [4] Otomatik Test ile 3 profili de deneyin.
- Otomatik test basarisizsa, once Compatibility (Fake) profilini elle
  deneyin - bu, gercek akisa en az mudahale eden profildir.
- Discord'un kendi WinDivert kullanan baska bir bilesenle cakismasi da
  mumkun; bilgisayarinizi yeniden baslatip tekrar deneyin.

## Roblox / Bloxstrap sorunlari
- Once Roblox'u (ve varsa Bloxstrap'i) tamamen kapatip Zapret Turkey'yi
  baslattiktan sonra yeniden acin.
- Strong (MultiSplit) profili bazi durumlarda Roblox asset yuklemelerini
  yavaslatabilir; Stable ile karsilastirin.

## DNS ile ilgili bir sorun yasadim
Varsayilan olarak bu program DNS ayarinizi HICBIR ZAMAN degistirmez.
Eger Ayarlar menusunden Cloudflare DNS'i siz elle actiysaniz, Ayarlar -
[3] "DNS'i otomatige (DHCP) geri al" secenegiyle geri alabilirsiniz.

## Hizmet (service) modu profil degisikligini yansitmiyor
Hizmet, kuruldugu anda secili olan profilin parametrelerini kullanir.
Profil degistirdiginizde Hizmet Ayarlari - [1] Hizmeti Kur secenegini
tekrar calistirmaniz gerekir; bu, hizmeti yeni parametrelerle yeniden
olusturur.

## Otomatik Test hicbir profili "basarili" gostermiyor
Bu test yalnizca temel HTTPS/TCP baglanti kurulup kurulamadigina bakar
(curl ile). Hicbiri gecmiyorsa sorun DPI bypass'tan degil, genel agin
kendisinden (ISS DNS/erisim engeli, internet baglantisi vb.) kaynaklaniyor
olabilir. Tanilama menusunu kullanip IPv4/IPv6 durumunu kontrol edin.

## VirusTotal / antivirus uyarisi
WinDivert.dll ve WinDivert64.sys, ag trafigini yakalayan surucu dosyalari
oldugu icin bazi antivirus yazilimlari yanlis pozitif verebilir. Bu proje
acik kaynakli WinDivert (LGPLv3) projesini kullanir - lisans metni
`licenses/LICENSE-windivert.txt` dosyasindadir. Guvenmiyorsaniz
binary'leri kendiniz inceleyebilir veya VirusTotal'da tarayabilirsiniz.

## Normal siteler (bankacılık, haber, e-posta vb.) erişilemez oluyor
Bu, eski bir tasarım sorunuydu: ilk sürümlerde desync **tüm** TCP/443
trafiğine uygulanıyordu, bu yüzden Discord/Roblox için gereken
paket bölme tekniği ilgisiz sitelere de bulaşıyordu. Artık
`profiles\target-hosts.txt` bir **hedef listesi** — desync SADECE bu
listedeki alan adlarına uygulanıyor (`--hostlist`), listede olmayan
her şey hiç dokunulmadan geçiyor. Yine de bir site bozuluyorsa:

1. O sitenin adresini `target-hosts.txt`'ye **eklemediğinizi**
   doğrulayın (yalnızca gerçekten bypass istediğiniz siteler orada
   olmalı).
2. `[9] Debug Mode`'dan son çalıştırılan komut satırını kontrol edin,
   `--hostlist="...\target-hosts.txt"` gerçekten görünüyor mu bakın.
3. Görünmüyorsa ve hizmet modundaysanız, `target-hosts.txt` dosyasını
   güncelledikten sonra Hizmet Ayarları - Hizmeti Kur'u **tekrar**
   çalıştırmanız gerekir (hizmet, kurulduğu andaki komut satırını
   kullanır, dosya değişikliğini kendiliğinden almaz).

## WhatsApp (web veya masaustu uygulama) hic acilmiyor / baglanmiyor
WhatsApp `target-hosts.txt` listesinde olmadigi icin normalde zaten
desync'ten etkilenmemesi gerekir. Ek bir guvenlik katmani olarak ayrica
`profiles\exclude-hosts.txt` uzerinden de acikca haric tutuluyor -
`--hostlist-exclude` parametresi sayesinde bu alan adlarina kesinlikle
hicbir mudahale yapilmiyor.

Eger WhatsApp (veya baska normalde calismasi gereken bir site/uygulama)
hala bozuluyorsa, once yukaridaki "Normal siteler erisilemez oluyor"
adimlarini uygulayin (buyuk ihtimalle `target-hosts.txt`'ye yanlislikla
eklenmis veya hizmet guncellenmemis olabilir). Hala cozulmuyorsa:

1. `profiles\exclude-hosts.txt` dosyasini bir metin editorunde acin.
2. Sorunlu sitenin alan adini yeni bir satira ekleyin (ornek: `example.com`
   yazmak, `www.example.com`, `cdn.example.com` gibi tum alt alan
   adlarini da otomatik kapsar). **`#` ile baslayan yorum satiri
   eklemeyin** - zapret'in hostlist ayristiricisi bunlari desteklemiyor.
3. Dosyayi kaydedin, Zapret Turkey'de [2] Durdur, sonra [1] Baslat ile
   yeniden baslatin (veya hizmet modundaysaniz Hizmet Ayarlari - Hizmeti
   Kur'u tekrar calistirin).

Bu dosya her uc profil (Stable/Compatibility/Strong) icin ortak calisir;
`profiles\stable.conf` gibi profil dosyalarinin kendisini degistirmenize
gerek yoktur.
