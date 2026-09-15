# Katkida Bulunma

Bu proje topluluk verisiyle buyur. En degerli katki turu: **kendi
ISS'inizde hangi profilin calistigini test edip paylasmak.**

## ISS test sonucu paylasmak
`docs/ISS.md` icindeki formati kullanarak bir GitHub Issue acin.
Lutfen gercek IP adresi, MAC adresi, bilgisayar adi veya kullanici adi
paylasmayin - Tanilama menusundeki "Diagnostic Report" bu bilgileri
zaten disarida birakir.

## Yeni profil onerisi
`profiles/` altina yeni bir `.conf` dosyasi eklerken:
- Sadece gercekten test edilmis, calistigi dogrulanmis winws.exe
  parametreleri kullanin.
- Hangi ISS/baglanti turunde test edildigini PR aciklamasinda belirtin.
- Mevcut `stable.conf` / `compatibility.conf` / `strong.conf` dosyalarini
  degistirmeyin; bunlar dogrulanmis referans profillerdir. Yeni bir
  profil icin yeni bir dosya ekleyin.

## Kod katkisi
`ZapretTurkey.bat` saf CMD/BAT'tir, PowerShell/.NET/Python bagimliligi
eklenmemesi tercih edilir. Degisiklik gonderirken:
- Windows 10 ve Windows 11'de gercekten test edin.
- DNS'i varsayilan olarak degistiren veya UDP/QUIC'i varsayilan olarak
  filtreleyen bir degisiklik gonderMEyin (bkz. proje felsefesi, README).
- Sahte "basarili" mesajlari eklemeyin; bir ozellik gercekten
  calismiyorsa PR'da acikca belirtin.
