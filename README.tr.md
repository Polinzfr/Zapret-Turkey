🌍 **Language:** [English](README.md) | [Türkçe](README.tr.md)

# Zapret Turkey

Türkiye'deki DPI tabanlı erişim engellemelerine karşı, tamamen BAT/CMD tabanlı, açık kaynaklı bir **Windows aracı**. [Zapret](https://github.com/bol-van/zapret) motorunu (`winws.exe`) kullanarak ISS seviyesindeki DPI müdahalesini Discord, Roblox ve Steam gibi uygulama ve sitelere olan bağlantılarda aşmaya çalışır — hepsi tek bir renkli CMD menüsünden. Kurulum programı, Python veya .NET gerekmez.

![Uygulama Ekran Görüntüsü](docs/screenshot(tr).png)

---

## Özellikler

- **Tek dosyalık CMD menüsü** — ANSI renkli, kurulum gerektirmez; Türkçe ve İngilizce arayüz, Ayarlar'dan istediğiniz zaman (yeniden başlatmadan) değiştirilebilir
- **Üç hazır profil** — Stable / Compatibility / Strong; kod içine gömülü değil, `profiles/` altında düz metin `.conf` dosyaları olarak tutulur
- **Otomatik Test** — üç profili sırayla dener, Discord, Roblox ve Steam'e temel bağlantı testleri yapar ve birini önerir; tamamen gizli çalışır, hiçbir pencere açılıp kapanmaz
- **Hedef / hariç tutma site listeleri** — bypass yalnızca `profiles/target-hosts.txt` içindeki sitelere uygulanır, geri kalan her şey olduğu gibi geçer; siteleri menüden ekleyip silebilir, tek bir siteyi anında test edebilirsiniz
- **Profil dışa / içe aktarma** — seçili profili bir config dosyasına kaydedin, normal Windows Kaydet / Aç pencereleriyle geri yükleyin
- **GitHub Issue raporu** — [`docs/ISS.md`](docs/ISS.md) formatında bir blok üretir (profil, IPv4/IPv6, DNS, Discord/Roblox/Steam sonuçları) ve panoya kopyalar
- **Windows hizmeti** — kurma, kaldırma, başlatma ve durdurma; açılışta hiçbir pencere açmadan başlar
- **Girişte otomatik başlatma** — hizmetsiz bir alternatif: gizli bir zamanlanmış görev, oturum açtıktan yaklaşık 15 saniye sonra motoru başlatır
- **Watchdog** — `winws.exe` çökerse yeniden başlatır; Durdur'a basarsanız buna saygı duyar, art arda 3 başarısız denemeden sonra vazgeçer
- **VPN otomatik duraklatma** — bir VPN (ProtonVPN, Windscribe ve diğer VPN adaptörleri) bağlıyken motoru durdurur, VPN yaklaşık 20 saniye boyunca yoksa yeniden başlatır; resmi WireGuard uygulaması yok sayılır; Windows hizmeti ile de çalışır
- **DNS Yardımcısı** — etkin ağ adaptörünüzü tespit eder, Cloudflare veya Google DNS ayarlar (IPv4, IPv6 ise yalnızca adaptörde gerçek bir IPv6 adresi varsa) ve sonucu doğrular; her zaman geri alınabilir (DHCP'ye sıfırlama)
- **Tanılama** — yönetici yetkisini, gerekli dosyaları, WinDivert tabanlı diğer yazılımları, IPv4/IPv6'yı, bağlantıyı (Discord, Roblox, Steam, genel HTTPS) ve **DNS**'i kontrol eder (sistemin cevapları `1.1.1.1` ile karşılaştırılır, modemin DNS'i sahte adres dönüyorsa uyarır); isteğe bağlı olarak kişisel veri içermeyen, paylaşılabilir bir rapor yazar
- **Debug Mode** — çözümlenen yollar, parse edilmiş profil parametreleri, yönetici/hizmet/çalışma durumu ve son başlatma denemesinin tam komut satırı ile stderr çıktısı tek ekranda
- **Ayrıntılı loglar** — `logs/app.log` ve `logs/engine_stderr.log`
- **Varsayılan olarak DNS ve UDP/QUIC'e dokunmaz** — DNS yalnızca siz DNS Yardımcısı'nı çalıştırırsanız değişir

---

## Bu Proje Ne YAPMAZ

- **Bir VPN değildir** — trafiğinizi şifrelemez veya başka bir sunucuya yönlendirmez; yalnızca TCP/443 el sıkışmasının paketleme şeklini değiştirir
- **DNS ayarınızı varsayılan olarak değiştirmez**
- **UDP/QUIC trafiğine dokunmaz**
- **Sizi izlemez, veri toplamaz, dışarıya bir şey göndermez** — IP bilgisi sorgusu yapılmaz, tanılama raporu gerçek IP, MAC adresi, bilgisayar adı, kullanıcı adı veya dosya yolu içermez

---

## Sistem Gereksinimleri

| Gereksinim | Ayrıntılar |
|------------|------------|
| İşletim Sistemi | Windows 10 / Windows 11 (x64) |
| Yetki | Yönetici — uygulama bunu kendisi ister, gerekirse yönetici olarak yeniden başlar |
| curl.exe | Windows 10 1803+ ve Windows 11'de yerleşik — Otomatik Test ve Tanılama kullanır |
| PowerShell | Windows'ta yerleşik — yalnızca isteğe bağlı özellikler kullanır (VPN algılama, dosya pencereleri, Tanılama'daki DNS kontrolü); başlat/durdur, profiller ve hizmet buna ihtiyaç duymaz |
| Python / .NET | Gerekmez |

---

## Kurulum

1. [Releases](https://github.com/Polinzfr/Zapret-Turkey/releases) sayfasından en son ZIP'i indirin (veya depoyu klonlayın):

```bash
git clone https://github.com/Polinzfr/Zapret-Turkey.git
```

2. Klasörü istediğiniz bir yere çıkarın — **sonradan taşımayın**. Windows hizmeti ve zamanlanmış görevler (girişte başlatma, Watchdog, VPN otomatik duraklatma) klasör yolunu hatırlar; taşırsanız bu özellikleri kapatıp yeniden açın ve hizmeti yeniden kurun.
3. `ZapretTurkey.bat` dosyasına çift tıklayın ve yönetici isteğini onaylayın.

---

## Kullanım

```
============================================================
   ZAPRET TURKEY - Turkiye DPI Bypass Utility
============================================================
  Durum        : DURDU
  Profil       : stable (Turkiye Stable (HostFakeSplit))
  DNS modu     : system
  Hizmet       : KURULU DEGIL
------------------------------------------------------------
  [1]  Baslat
  [2]  Durdur
  [3]  Profil - degistir / disa aktar / ice aktar
  [4]  Otomatik Test
  [5]  Hizmet Ayarlari
  [6]  Tanilama
  [7]  Ayarlar
  [8]  Gunlukler
  [9]  Araclar
  [0]  Cikis
------------------------------------------------------------
```

1. `ZapretTurkey.bat` dosyasını çalıştırın
2. **[4] Otomatik Test**'i seçin ve önerilen profili kaydedin (veya **[3] Profil**'den kendiniz seçin)
3. **[1] Baslat**'a basın
4. Discord, Roblox veya test ettiğiniz uygulamayı tamamen kapatıp yeniden açın
5. İsteğe bağlı: **[5] Hizmet Ayarlari** ile hizmet olarak çalıştırın, girişte başlatın veya Watchdog / VPN otomatik duraklatmayı açın
6. Bir şey çalışmazsa **[6] Tanilama**'yı çalıştırın

| Menü | Ne yapar |
|---|---|
| **[1] Başlat / [2] Durdur** | Seçili profille `winws.exe`'yi başlatır veya durdurur. Başarısız olursa gerçek neden ekranda gösterilir (dosya eksik, profil bozuk, yönetici değil, motor hemen kapandı + stderr metni) — pencere sessizce kapanmaz. |
| **[3] Profil** | Profili değiştirin, bir dosyaya dışa aktarın, bir dosyadan içe aktarın veya GitHub Issue raporu üretin. |
| **[4] Otomatik Test** | Stable / Compatibility / Strong'u sırayla, gizli olarak dener ve `STABLE = PASS/FAIL` şeklinde özetler. |
| **[5] Hizmet Ayarları** | [1]-[4] Windows hizmetini kur / kaldır / başlat / durdur, [5]/[6] girişte başlatmayı aç/kapat, [7]/[8] Watchdog'u aç/kapat, [9]/[10] VPN otomatik duraklatmayı aç/kapat. Windows hizmeti kuruluyken girişte başlatma ve Watchdog kullanılamaz, çünkü hizmet motoru zaten açılışta başlatır. |
| **[6] Tanılama** | Sistem, WinDivert çakışması, IPv4/IPv6, bağlantı ve DNS kontrolleri; isteğe bağlı olarak `logs/diagnostic-report.txt` yazar. |
| **[7] Ayarlar** | [1] DNS'e dokunma, [2] DNS Yardımcısı (Cloudflare veya Google), [3] DNS'i otomatiğe (DHCP) geri al, [4] debug etiketi, [5] dil. |
| **[8] Günlükler** | Son logları ve hataları gösterir, log klasörünü açar, son motor stderr çıktısını gösterir. |
| **[9] Araçlar** | [1] site listelerini düzenle, [2] belirli bir siteyi test et, [3] Debug Mode, [4] VPN algılama testi. |

---

## Profiller

| Profil | Yöntem | Notlar |
|---|---|---|
| **Stable** | `--dpi-desync=hostfakesplit` | SNI/host konumundan hemen sonra hafif bölme — en az müdahaleci profillerden biri |
| **Compatibility** | `--dpi-desync=fake` | Gerçek akışa daha az dokunan sahte-paket profili |
| **Strong** | `--dpi-desync=multisplit` | method ve host konumlarında daha güçlü bölme |

Üçü de yalnızca **TCP/443** üzerinde ve yalnızca `profiles/target-hosts.txt` içindeki sitelerde çalışır (`profiles/exclude-hosts.txt` içindeki sitelere hiç dokunulmaz). **UDP/QUIC filtrelenmez**, çünkü önceki testlerde agresif UDP müdahalesi Discord ve Roblox'u bozuyordu — bkz. [`docs/ANALYSIS.md`](docs/ANALYSIS.md). Profil eklemek için `.bat` dosyasını değil, yalnızca `profiles/` klasörünü düzenlemeniz yeterli. Windows hizmetini kurduysanız, yeni parametrelerin geçerli olması için profili değiştirdikten sonra hizmeti yeniden kurun.

```ini
# profiles/stable.conf
NAME=Turkiye Stable (HostFakeSplit)
PORT_TCP=443
ARGS=--dpi-desync=hostfakesplit --dpi-desync-split-pos=sld --dpi-desync-repeats=1 --dpi-desync-autottl=1:4-10 --dpi-desync-skip-nosni=0 --dpi-desync-start=n2 --dpi-desync-cutoff=n5
```

---

## DNS ve IPv6 Notları

- Bazı ISS modemleri ve yönlendiricileri, engelli alan adları (örneğin `discord.com`) için DNS sorgularına sahte bir adresle cevap verir. O zaman hangi profil çalışırsa çalışsın bağlantılar sertifika hatasıyla başarısız olur. **Tanılama**, sisteminizin cevaplarını `1.1.1.1` ile karşılaştırır ve bu durumu size söyler; **Ayarlar → DNS Yardımcısı** Cloudflare veya Google DNS'e geçirir, **Ayarlar → [3]** ise otomatiğe geri alır.
- ISS'niz veya modeminiz IPv6 sağlamıyorsa, adaptörün DNS listesinin en üstündeki bir IPv6 DNS sunucusuna (modemin `fe80::` adresi veya elle girilmiş bir adres) ulaşılamaz. Windows bir sonraki sunucuya geçtiği için uygulamalar çalışmaya devam eder, ama yalnızca ilk sunucuyu sorgulayan `nslookup` gibi araçlar zaman aşımına uğrar. Bu bir Zapret Turkey hatası değildir. DNS Yardımcısı, IPv6 DNS'i yalnızca adaptörde gerçek bir IPv6 adresi varsa önerir.

---

## Proje Yapısı

```
Zapret-Turkey/
├── ZapretTurkey.bat        # Ana menü / uygulama
├── engine/                 # Zapret motoru (winws.exe, WinDivert.dll, WinDivert64.sys, ...)
├── profiles/               # Düz metin profiller ve site listeleri
│   ├── stable.conf
│   ├── compatibility.conf
│   ├── strong.conf
│   ├── target-hosts.txt    # Bypass'ın uygulandığı siteler
│   └── exclude-hosts.txt   # Hiç dokunulmayan siteler
├── lang/                   # Arayüz dil dosyaları
│   ├── en.lang
│   └── tr.lang
├── scripts/
│   ├── lang-load.bat
│   ├── install-service.bat
│   ├── uninstall-service.bat
│   └── diagnostics.bat
├── config/                 # settings.conf ve küçük durum dosyaları (çalışırken oluşur)
├── logs/                   # app.log, engine_stderr.log, tanılama raporu (çalışırken oluşur)
├── licenses/
│   └── LICENSE-windivert.txt
├── docs/
│   ├── ANALYSIS.md         # GoodbyeDPI ve Zapret teknik karşılaştırması
│   ├── ISS.md              # Topluluk tarafından doldurulacak ISS-profil şablonu
│   ├── TROUBLESHOOTING.md
│   └── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
├── README.md               # İngilizce belge
└── README.tr.md            # Türkçe belge
```

---

## Teknoloji Yığını

| Katman | Teknoloji |
|--------|-----------|
| Motor | [Zapret](https://github.com/bol-van/zapret) (`winws.exe`) |
| Paket sürücüsü | [WinDivert](https://github.com/basil00/Divert) (LGPLv3, lisans metni `licenses/` altında) |
| Arayüz | ANSI renkli BAT/CMD |
| Bağlantı testleri | `curl.exe` (Windows'ta yerleşik) |
| Arka plan görevleri | Windows Görev Zamanlayıcı (`schtasks`) ve gizli VBScript başlatıcıları |
| İsteğe bağlı özellikler | Windows PowerShell (VPN algılama, dosya pencereleri, DNS kontrolü) |

---

## Bilinen Sınırlamalar

- **Her ISS için tek ve garantili bir profil yoktur.** FTTH/VDSL/ADSL/GPON, farklı modem ve yönlendiriciler, IPv4/IPv6/CGNAT gibi değişkenlerin hepsi DPI davranışını etkileyebilir. [`docs/ISS.md`](docs/ISS.md) topluluk tarafından doldurulacak bir şablondur ve bilinçli olarak uydurma bir ISS eşlemesi içermez. Kendi ISS'inizde hangi profilin çalıştığını test edip bir Issue veya PR ile paylaşmanız en değerli katkıdır.
- Otomatik Test yalnızca temel TCP/TLS bağlantısını kontrol eder; uygulama içi davranışı (mesajlaşma, CDN, WebSocket) doğrulamaz — bunun için uygulamaları kendiniz açıp deneyin.
- VPN algılama, ağ adaptörü adlarına ve açıklamalarına ve Windows VPN bağlantılarına dayanır. VPN'iniz algılanmazsa **Araçlar → [4] VPN Algılama Testi**'ni çalıştırın ve çıktısıyla bir Issue açın.
- Tanılama'daki IPv6 satırı link-local adresleri (`fe80::`) de sayar, bu yüzden ISS'niz IPv6 sağlamasa bile "VAR" diyebilir.
- Şu ana kadar tek bir kullanıcı, makine ve ISS üzerinde test edildi. Farklı bir Windows sürümü, ISS veya ağ yapılandırmasında karşılaştığınız sorunlar için lütfen Issue açın — **[3] Profil → GitHub Issue raporu** ve Tanılama raporu bunu hızlandırır.
- **GoodbyeDPI ile birlikte çalıştırmayın** — ikisi de WinDivert sürücüsünü kullanır ve çakışabilir (Tanılama bunu kontrol eder). Karşılaştırma için [`docs/ANALYSIS.md`](docs/ANALYSIS.md) dosyasına bakın.

Yaygın sorunlar ve çözümleri için [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) dosyasına bakın.

---

## Katkıda Bulunma

1. Depoyu fork'layın
2. Bir feature branch oluşturun (`git checkout -b feature/yeni-ozellik`)
3. Değişikliklerinizi commit edin
4. Pull Request açın

Tam rehber için [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) dosyasına bakın.

---

## Lisans

Bu depodaki BAT/CMD betikleri ve dokümantasyon [MIT Lisansı](LICENSE) ile lisanslanmıştır. `engine/` altındaki ikili dosyalar kendi upstream projelerinin (Zapret, WinDivert) lisans şartlarına tabidir.

---

## Sorumluluk Reddi

Bu araç yalnızca kendi bağlantılarınızın paketlenme şeklini değiştirir; herhangi bir siteye veya servise erişimi garanti etmez ve bir VPN değildir. Sorumlu bir şekilde kullanın; tabi olduğunuz yasalara ve kullandığınız platformların kullanım şartlarına uyun.
