# Changelog

## [0.1.0] - İlk sürüm (henüz gerçek Windows'ta test edilmedi)

### Eklendi
- `ZapretTurkey.bat`: renkli ana menü (Başlat/Durdur/Profil Değiştir/
  Otomatik Test/Hizmet Ayarları/Tanılama/Ayarlar/Günlükler/Çıkış)
- `profiles/stable.conf`, `compatibility.conf`, `strong.conf`: kullanıcının
  doğrulanmış `baslat.bat` dosyasından değiştirilmeden aktarılan
  HOSTFAKESPLIT / FAKE / MULTISPLIT profilleri
- `scripts/install-service.bat`, `scripts/uninstall-service.bat`:
  seçili profille Windows hizmeti kurma/kaldırma (GoodbyeDPI Turkey'nin
  doğrulanmış `sc create` deseni referans alındı)
- `scripts/diagnostics.bat`: dosya/servis/çakışma/IPv4-IPv6/bağlantı
  kontrolü ve sanitized tanılama raporu
- Yönetici yetkisi kontrolü ve otomatik yükseltme istemi
- Opsiyonel, varsayılan olarak kapalı DNS değiştirme (Cloudflare) ve
  geri alma seçeneği
- Debug modu: `winws.exe` çıktısını `logs/engine.log`'a yazma
- `docs/ANALYSIS.md`: GoodbyeDPI Turkey ile Zapret profilinin gerçek
  parametrelere dayalı karşılaştırması
- `docs/ISS.md`: topluluk tarafından doldurulacak boş ISS-profil şablonu
- `docs/TROUBLESHOOTING.md`, `docs/CONTRIBUTING.md`

### Uygulanmadı (bilinçli olarak, gerekçesiyle)
- Otomatik ISS tespiti (bkz. README "Güvenlik/gizlilik")
- ISS-bazlı önceden doldurulmuş profil eşlemesi (bkz. `docs/ISS.md`)
- Discord/Roblox/Steam için uygulama-seviyesi (yalnızca temel TCP/TLS
  değil) otomatik test

### Bilinen durum
Gerçek Windows ortamında uçtan uca test edilmedi. Bkz. README
"Bilinen sınırlamalar".

## [0.1.2] - Fazla cmd penceresi sorunu duzeltildi
- `ENGINE_START_CORE`, winws.exe'yi artik dogrudan baslatiyor (araya
  bir cmd.exe "wrapper" penceresi konmuyor). Onceki surumde her
  Baslat/Otomatik Test adiminda ekstra bir cmd penceresi aciliyordu.
- stdout/stderr yakalama `start` satirinin kendisinde dogrudan dosyaya
  yonlendirilerek yapiliyor; ekstra pencere/islem yok.
- Bedeli: sayisal exit code artik yakalanmiyor (stderr metni zaten
  asil tanı bilgisiydi, korunuyor).

## [0.1.3] - Otomatik Test artik hicbir pencere acmiyor
- `ENGINE_START_CORE`'a VISIBLE/HIDDEN modu eklendi.
  - Baslat menusu ([1]) hala oncekiyle ayni: winws.exe kendi ayri,
    kucultulmus penceresinde calisir (bu kalici, kullanicinin gormek
    istedigi surec oldugu icin degistirilmedi).
  - Otomatik Test artik HIDDEN modu kullaniyor: winws.exe her profil
    denemesinde VBS "gizli calistirma" hilesiyle (WScript.Shell.Run,
    pencere stili 0) baslatiliyor - hicbir pencere acilip kapanmiyor.

## [0.1.4] - WhatsApp uyumlulugu
- WhatsApp (web.whatsapp.com + masaustu/mobil uygulamanin kullandigi
  whatsapp.net) DPI desync'ten TAMAMEN haric tutuldu. TCP/443 uzerinden
  DPI desync uygulandiginda WhatsApp'in sunucu tarafi baglantiyi
  tamamen reddediyordu (Discord/Roblox'un aksine tolere etmiyor).
- Yeni `profiles/exclude-hosts.txt`: `--hostlist-exclude` ile
  calisir, kullanici tarafindan duzenlenebilir, uc profil (Stable/
  Compatibility/Strong) icin de ortak. `profiles/*.conf` dosyalarinin
  KENDISI DEGISTIRILMEDI - haric tutma listesi calisma zamaninda
  ENGINE_START_CORE tarafindan komut satirina ekleniyor.

## [0.1.5] - Hizmet modu WhatsApp haric tutma listesini kullanmiyordu (duzeltildi)
- `scripts/install-service.bat` kendi komut satirini bagimsiz olarak
  olusturuyordu ve ENGINE_START_CORE'a eklenen `--hostlist-exclude`
  mantigini bilmiyordu - servis calisirken (Hizmet Ayarlari - Hizmeti
  Kur ile kurulmus) WhatsApp haric tutulmuyordu, sadece [1] Baslat
  ile manuel calistirmada uygulaniyordu.
- Ayni haric tutma mantigi artik install-service.bat'a da eklendi.
- ONEMLI: eger hizmeti ONCEDEN kurduysaniz, degisikligin gecerli
  olmasi icin Hizmet Ayarlari - [1] Hizmeti Kur'u TEKRAR calistirmaniz
  gerekir (bu, mevcut hizmeti siler ve guncel parametrelerle yeniden
  olusturur).

## [0.1.6] - Hedef liste (--hostlist) ile normal siteler artik bozulmuyor
- YENI `profiles/target-hosts.txt`: Discord, Roblox ve Steam alan
  adlarini iceren bir "dahil etme listesi". `--hostlist` parametresiyle
  desync artik SADECE bu listedeki adreslere uygulaniyor - listede
  olmayan HER SEY (normal web siteleri) hic dokunulmadan geciyor.
  Onceden `--wf-tcp=443` TUM TCP/443 trafigine uygulaniyordu, bu da
  WhatsApp gibi ilgisiz sitelerin surekli bozulmasina yol aciyordu.
- `profiles/exclude-hosts.txt` (WhatsApp icin) ARTIK YORUM SATIRI
  ICERMIYOR - zapret'in resmi deposunda (bol-van/zapret, Issue #1847,
  Ekim 2025) hostlist dosyalarinin `#` yorumlarini DESTEKLEMEDIGI
  dogrulandi; onceki surumdeki yorumlar muhtemelen gecersiz "hostname"
  olarak okunuyordu. Aciklamalar artik dosyanin kendisinde degil bu
  CHANGELOG ve docs/TROUBLESHOOTING.md'de.
- Hem `ZapretTurkey.bat` (ENGINE_START_CORE) hem `scripts/install-service.bat`
  guncellendi - ayni mantik iki yerde de tutarli (onceki turda
  install-service.bat'in unutulmasi bir bug'a yol acmisti, bu sefer
  ikisi birden guncellendi).
- Yeni site/uygulama eklemek icin: `profiles/target-hosts.txt`'ye satir
  eklemeniz yeterli - kod degisikligi gerekmez.

### Otomatik ISS tespiti hakkinda (uygulanmadi - gerekcesiyle)
Zapret'in resmi deposunu arastirdim: `--hostlist-auto=<dosya>` diye
gercek bir "engellenen siteleri otomatik tespit et" ozelligi var, ama
resmi dokumantasyonda bunun "gelen trafigin de yonlendirilmesini
gerektirdigi" belirtiliyor - mevcut `--wf-tcp=443` filtremizle bunun
dogru calisip calismayacagini gercek Windows'ta test etmeden
DOGRULAYAMIYORUM. Bu proje zaten birkac turdur "gercek Windows'ta
denemeden hazir demeyecegim" ilkesiyle ilerledigi icin, bu ozelligi
simdilik EKLEMEDIM - riskli, dogrulanmamis bir ekleme yerine, zaten
var olan ve şimdi güvenli hale gelen bir mekanizmayi one cikariyorum:
`--hostlist` sayesinde artik butun profiller SADECE Discord/Roblox/
Steam'i etkiliyor, yani `[4] Otomatik Test` her ISS/ag icin risksizce
"hangi profil calisiyor" sorusuna cevap verebilir - bu, ISS ismini
bilmeden ayni sonuca ulasan, dogrulanabilir bir yol.
