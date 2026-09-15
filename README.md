<div align="center">

# Zapret Turkey

**Türkiye'deki DPI/erişim engellemelerine karşı, tamamen BAT/CMD tabanlı, açık kaynaklı Windows aracı.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%2F%2011-0078D6)](#desteklenen-windows-sürümleri)
[![Engine](https://img.shields.io/badge/engine-Zapret%20(winws.exe)-blue)](docs/ANALYSIS.md)
[![PowerShell/.NET/Python](https://img.shields.io/badge/dependencies-none-brightgreen)](#kurulum)

</div>

---

> ZIP'i indir → klasörü çıkar → `ZapretTurkey.bat`'ı çalıştır → profili seç → Başlat.

Hepsi bu kadar. PowerShell, Python, .NET veya ayrı bir GUI kurulumu **gerekmez.**

## İçindekiler

- [Bu proje ne yapar?](#bu-proje-ne-yapar)
- [Bu proje ne YAPMAZ](#bu-proje-ne-yapmaz)
- [Öne çıkan özellikler](#öne-çıkan-özellikler)
- [Desteklenen Windows sürümleri](#desteklenen-windows-sürümleri)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
- [Profil sistemi](#profil-sistemi)
- [Proje yapısı](#proje-yapısı)
- [Hizmet (Windows service) modu](#hizmet-windows-service-modu)
- [Tanılama ve loglar](#tanılama-ve-loglar)
- [Debug Mode](#debug-mode)
- [ISS desteği](#iss-desteği)
- [Discord / Roblox / Steam uyumluluğu](#discord--roblox--steam-uyumluluğu)
- [Güvenlik ve gizlilik](#güvenlik-ve-gizlilik)
- [GoodbyeDPI ile farkı](#goodbyedpi-ile-farkı)
- [Sorun giderme](#sorun-giderme)
- [Katkıda bulunma](#katkıda-bulunma)
- [Bilinen sınırlamalar](#bilinen-sınırlamalar)
- [Teşekkürler / Lisans](#teşekkürler--lisans)

## Bu proje ne yapar?

Türkiye'de bazı ISS'lerin DPI (Derin Paket İnceleme) sistemleri, belirli
uygulamalarla (ör. Discord, Roblox) ve sitelerle olan TCP bağlantılarını
bozabiliyor. Bu araç [Zapret](docs/ANALYSIS.md) projesinin motoru olan
`winws.exe`'yi kullanarak TCP el sıkışmasını DPI'nin tanıyamayacağı,
zararsız küçük değişikliklerle göndererek bu tespiti atlatmaya çalışır
(paket bölme / sahte paket teknikleri). `ZapretTurkey.bat`, bu motoru
yönetmek için tek dosyalık, renkli bir CMD arayüzü sağlar: profil
seçimi, başlatma/durdurma, otomatik profil testi, Windows hizmeti olarak
kurulum ve tanılama.

## Bu proje ne YAPMAZ

- **Bir VPN değildir.** Trafiğinizi şifrelemez veya başka bir sunucuya
  yönlendirmez; yalnızca TCP/443 el sıkışmasının paketleme şeklini
  değiştirir.
- **DNS ayarınızı varsayılan olarak değiştirmez.**
- **UDP/QUIC trafiğine dokunmaz** (bkz. [Profil sistemi](#profil-sistemi)).
- **Sizi izlemez, veri toplamaz veya dışarıya bir şey göndermez** —
  bkz. [Güvenlik ve gizlilik](#güvenlik-ve-gizlilik).
- Her ISS'de %100 çalışacağını garanti etmez — bkz. [ISS desteği](#iss-desteği).

## Öne çıkan özellikler

- 🎨 Tek dosyalık, ANSI renkli CMD menüsü — kurulum gerektirmez
- 🔀 Üç hazır profil: **Stable / Compatibility / Strong** (düz metin `.conf` dosyaları, kod içine gömülü değil)
- 🧪 **Otomatik Test** — üç profili sırayla dener, temel bağlantı testleriyle hangisinin çalıştığını raporlar, hiçbir pencere açıp kapatmadan (arka planda tamamen gizli çalışır)
- 🩺 **Tanılama** menüsü — dosya/servis/WinDivert çakışma/bağlantı kontrolü + paylaşılabilir, kişisel veri içermeyen rapor
- 🛠️ **Debug Mode** — son başlatma denemesinin tam komut satırı, stderr çıktısı ve durumu tek ekranda
- ⚙️ **Windows hizmeti** olarak kurulum/kaldırma (açılışta otomatik başlama)
- 🔒 DNS ve UDP/QUIC'e **varsayılan olarak dokunmaz**
- 📝 Ayrıntılı loglar (`logs/app.log`, `logs/engine_stderr.log`)
- 🇹🇷 Baştan sona Türkçe arayüz ve dokümantasyon

## Desteklenen Windows sürümleri

Windows 10 ve Windows 11 (x64). `ZapretTurkey.bat` PowerShell yerine
sade CMD/BAT kullanır. **Otomatik Test** özelliği Windows'a önceden
yüklü gelen `curl.exe`'ye ihtiyaç duyar (Windows 10 1803+ ve
Windows 11'de varsayılan olarak mevcuttur).

## Kurulum

1. [Releases](../../releases) sayfasından en son ZIP'i indirin (veya
   bu depoyu klonlayın).
2. Klasörü istediğiniz bir yere çıkarın — **çıkardıktan sonra
   taşımayın**, hizmet kurulumu dosya yoluna bağlıdır.
3. `ZapretTurkey.bat` dosyasına çift tıklayın.
4. Yönetici yetkisi istenirse onaylayın (program bunu kendisi sorar ve
   gerekirse otomatik olarak yönetici modunda yeniden başlar).

## Kullanım

```
╔══════════════════════════════════════════════════════════╗
   ZAPRET TURKEY - Turkiye DPI Bypass Utility
╠══════════════════════════════════════════════════════════╣
  Durum        : DURDU
  Profil       : stable (Turkiye Stable (HostFakeSplit))
  DNS modu     : system
  Hizmet       : KURULU DEGIL
╠══════════════════════════════════════════════════════════╣
  [1]  Baslat
  [2]  Durdur
  [3]  Profil Degistir
  [4]  Otomatik Test
  [5]  Hizmet Ayarlari
  [6]  Tanilama
  [7]  Ayarlar
  [8]  Gunlukler
  [9]  Debug Mode
  [0]  Cikis
╚══════════════════════════════════════════════════════════╝
```

| Menü | Ne yapar |
|---|---|
| **[1] Başlat / [2] Durdur** | Seçili profille `winws.exe`'yi başlatır/durdurur. Başarısız olursa gerçek nedeni (dosya eksik, profil bozuk, admin yok, motor hemen kapandı + stderr metni) ekranda gösterir — pencere sessizce kapanmaz. |
| **[3] Profil Değiştir** | Stable / Compatibility / Strong arasında geçiş yapar. |
| **[4] Otomatik Test** | Üç profili sırayla, **hiçbir pencere açmadan** dener; Discord/Roblox/Steam alan adlarına temel TCP/TLS bağlantı testi yapar ve `STABLE = PASS/FAIL` şeklinde özetler. |
| **[5] Hizmet Ayarları** | Windows açılışında otomatik başlayan bir hizmet olarak kurar/kaldırır. |
| **[6] Tanılama** | Dosya/servis/WinDivert çakışma/IPv4-IPv6/bağlantı kontrolü yapar; isteğe bağlı olarak kişisel veri içermeyen bir rapor (`logs/diagnostic-report.txt`) üretir. |
| **[7] Ayarlar** | DNS (varsayılan: dokunulmaz, isteğe bağlı Cloudflare) ve debug etiketi. |
| **[8] Günlükler** | `logs/` klasöründeki kayıtları görüntüler. |
| **[9] Debug Mode** | Çözümlenen yollar, seçili profilin parse edilmiş parametreleri, admin/hizmet/çalışma durumu ve son başlatma denemesinin tam detayını gösterir. |

## Profil sistemi

| Profil | Yöntem | Notlar |
|---|---|---|
| **Stable** | `--dpi-desync=hostfakesplit` | SNI/host konumundan hemen sonra hafif bölme — en az müdahaleci profillerden biri |
| **Compatibility** | `--dpi-desync=fake` | Gerçek akışa daha az dokunan sahte-paket profili |
| **Strong** | `--dpi-desync=multisplit` | method+host konumlarından daha güçlü bölme |

Üçü de yalnızca **TCP/443** üzerinde çalışır. **UDP/QUIC filtrelenmez**,
çünkü önceki testlerde agresif UDP müdahalesi Discord/Roblox'u
bozuyordu — bkz. [`docs/ANALYSIS.md`](docs/ANALYSIS.md). Profil
dosyaları `profiles/*.conf` altında düz metin olarak tutulur; yeni bir
profil eklemek için `.bat` dosyasını değil, sadece bu klasörü
düzenlemeniz yeterli.

```ini
# profiles/stable.conf
NAME=Turkiye Stable (HostFakeSplit)
PORT_TCP=443
ARGS=--dpi-desync=hostfakesplit --dpi-desync-split-pos=sld --dpi-desync-repeats=1 --dpi-desync-autottl=1:4-10 --dpi-desync-skip-nosni=0 --dpi-desync-start=n2 --dpi-desync-cutoff=n5
```

## Proje yapısı

```
ZapretTurkey/
├── ZapretTurkey.bat        # Ana menü / uygulama
├── README.md
├── CHANGELOG.md
├── LICENSE
├── engine/                 # Zapret motoru (winws.exe, WinDivert)
│   ├── winws.exe
│   ├── WinDivert.dll
│   ├── WinDivert64.sys
│   └── ...
├── profiles/                # Düz metin profil tanımları
│   ├── stable.conf
│   ├── compatibility.conf
│   └── strong.conf
├── config/
│   └── settings.conf        # Kullanıcı ayarları (secili profil, DNS modu...)
├── logs/                    # app.log, engine_stderr.log, tanılama raporu
├── scripts/
│   ├── install-service.bat
│   ├── uninstall-service.bat
│   └── diagnostics.bat
├── licenses/
│   └── LICENSE-windivert.txt
└── docs/
    ├── ANALYSIS.md           # GoodbyeDPI vs Zapret teknik karşılaştırması
    ├── ISS.md                # Topluluk tarafından doldurulacak ISS-profil tablosu
    ├── TROUBLESHOOTING.md
    └── CONTRIBUTING.md
```

## Hizmet (Windows service) modu

`[5] Hizmet Ayarları` menüsünden kurulan hizmet:

- Windows açılışında **otomatik** başlar,
- konsol penceresi **açmaz**,
- kurulduğu andaki profille çalışır — **profil değiştirdiğinizde
  hizmeti yeniden kurmanız gerekir** (menü bunu hatırlatır).

## Tanılama ve loglar

`[6] Tanılama`: yönetici durumu, gerekli dosyalar, olası WinDivert
tabanlı başka yazılımlarla çakışma, IPv4/IPv6 durumu ve
Discord/Roblox/Steam/genel HTTPS'e temel bağlantı testini kontrol
eder. Oluşturduğu rapor **gerçek IP, MAC adresi, bilgisayar adı,
kullanıcı adı veya dosya yolu içermez** — GitHub Issue'ya doğrudan
yapıştırılabilir.

## Debug Mode

`[9] Debug Mode`, "neden çalışmıyor" sorusunu tek ekranda cevaplamak
için var: çözümlenen `ROOT`/`ENGINE_DIR`/`PROFILE_DIR` yolları, seçili
profilin parse edilen `ARGS`/`PORT` değerleri, yönetici/hizmet/çalışma
durumu ve bu oturumdaki son başlatma denemesinin tam komut satırı +
stderr çıktısı.

## ISS desteği

**Her ISS için tek ve garantili bir profil yoktur.** Aynı ISS içinde
bile FTTH/VDSL/ADSL/GPON, farklı modem/router, IPv4/IPv6/CGNAT gibi
değişkenler DPI davranışını etkileyebilir.
[`docs/ISS.md`](docs/ISS.md) topluluk tarafından doldurulacak bir
şablon olarak eklendi — şu an için hiçbir ISS'e özel varsayım
**içermiyor**. Kendi ISS'inizde hangi profilin çalıştığını test edip
bir Issue/PR ile paylaşmanız en değerli katkı türüdür.

## Discord / Roblox / Steam uyumluluğu

Öncelik sırası: önce Discord, sonra Roblox, sonra Steam, sonra genel
web, en son bypass kapsamını artırma. `[4] Otomatik Test` bu üçü için
temel TCP/TLS bağlantı testi yapar; uygulama içi davranışı (mesaj
gecikmesi, CDN/görsel yükleme, WebSocket bağlantısı) doğrulamaz —
bunun için uygulamaları elle açıp test etmeniz gerekir.

## Güvenlik ve gizlilik

- DNS varsayılan olarak **değiştirilmez** (`[7] Ayarlar`dan isteğe
  bağlı olarak Cloudflare açılabilir, her zaman geri alınabilir).
- Otomatik ISS tespiti için dışarıya bir IP-bilgi sorgusu
  **yapılmaz** — bu, her açılışta genel IP'nizi üçüncü bir servise
  göndermek anlamına gelirdi; bilinçli olarak eklenmedi.
- `WinDivert.dll` / `WinDivert64.sys` açık kaynaklı [WinDivert]
  projesine (LGPLv3) aittir — lisans metni `licenses/` altındadır.
- Tanılama raporu kişisel/tanımlayıcı bilgi içermez (bkz. yukarı).

## GoodbyeDPI ile farkı

Bu projeyi hazırlarken GoodbyeDPI Turkey paketi ile karşılaştırmalı bir
teknik analiz yapıldı — gerçek parametreler her iki binary'den de
çıkarılarak karşılaştırıldı (uydurulmadı). Ayrıntılar için:
[`docs/ANALYSIS.md`](docs/ANALYSIS.md).

Özet: GoodbyeDPI fragmentasyon + (opsiyonel) DNS paket yönlendirmesi
kullanırken, Zapret motoru SNI/host/method konumuna göre TCP bölme +
sahte paket kullanır; ikisi arasında birebir parametre karşılığı
yoktur. **Aynı anda ikisini birden çalıştırmayın** — ikisi de
WinDivert sürücüsünü kullanır ve çakışabilir (Tanılama menüsü bunu
kontrol eder).

## Sorun giderme

Yaygın sorunlar ve çözümleri için [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)
dosyasına bakın. Çözemediğiniz bir sorun için Issue açarken `[6] Tanılama`
menüsünden oluşturduğunuz raporu ve `[9] Debug Mode` ekran görüntüsünü
eklemeniz süreci hızlandırır.

## Katkıda bulunma

Katkı rehberi için [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).
Özellikle değerli olan katkı: kendi ISS'inizde hangi profilin
çalıştığını test edip [`docs/ISS.md`](docs/ISS.md) formatıyla bir
Issue/PR açmak.

## Bilinen sınırlamalar

- Otomatik ISS tespiti henüz yok (bkz. [Güvenlik ve gizlilik](#güvenlik-ve-gizlilik))
  — profil seçimi elle veya `[4] Otomatik Test` ile yapılır.
- `docs/ISS.md` bilinçli olarak boş — gerçek olmayan ISS-profil
  eşlemesi eklenmedi; topluluk verisiyle dolacak.
- Otomatik Test yalnızca temel TCP/TLS bağlantısını doğrular;
  uygulama içi davranışı (mesajlaşma, CDN, WebSocket) doğrulamaz.
- Şu ana kadar tek bir kullanıcı/makine/ISS üzerinde test edildi.
  Farklı Windows sürümü, farklı ISS veya farklı ağ yapılandırmasında
  karşılaşılan sorunlar için lütfen Issue açın.

## Teşekkürler / Lisans

- Motor: [Zapret](https://github.com/bol-van/zapret) (`winws.exe`)
- Sürücü: [WinDivert](https://github.com/basil00/Divert) (LGPLv3) —
  lisans metni `licenses/LICENSE-windivert.txt`
- Referans karşılaştırma: GoodbyeDPI Turkey paketi

Bu depodaki BAT/CMD betikleri ve dokümantasyon [MIT Lisansı](LICENSE)
ile lisanslanmıştır. `engine/` altındaki ikili dosyalar kendi upstream
projelerinin lisans şartlarına tabidir.

---

<div align="center">

Bu proje, Türkiye'deki DPI engellemelerine karşı açık kaynaklı bir
topluluk çabasıdır. Katkılarınızı bekliyoruz. ⭐

</div>
