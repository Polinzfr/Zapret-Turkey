# Teknik Degerlendirme: GoodbyeDPI Turkey vs Zapret

Bu dosya, projeye baslamadan once istenen karsilastirmadir. Asagidaki tum
parametreler, yuklenen `goodbyedpi-0.2.3rc3-turkey.zip` ve `winws.exe`
dosyalarindan **gercekten cikarilmistir** (goodbyedpi.exe ve winws.exe
binary'lerinin gomulu yardim metinleri `strings` ile okunmustur). Hicbir
deger internetten veya bellekten varsayilarak yazilmamistir.

## 1. GoodbyeDPI Turkey'de calisan sey

Ana komut dosyasi `turkey_dnsredir.cmd`:

```
goodbyedpi.exe -5 --set-ttl 5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253
```

`goodbyedpi.exe` binary'sinin gomulu yardim metninden, `-5` on tanimli
setinin gercek karsiligi:

```
-5   -f 2 -e 2 --auto-ttl --reverse-frag --max-payload
```

Yani `-5`: HTTP parcalama=2, HTTPS parcalama=2, otomatik TTL tespiti,
ters sirali fragmentasyon (reverse-frag) ve max-payload birlesimidir.

`--set-ttl 5` ayrica **Fake Request Mode**'u sabit TTL=5 ile aktif eder
(bu, autottl ile ayni anda kullanildiginda set-ttl override eder - iki
farkli TTL stratejisinin ayni satirda kullanilmasi kaynak dosyada boyle).

`--dns-addr` / `--dns-port` ise onemli bir nokta: goodbyedpi.exe yardim
metninde bu net sekilde belirtiliyor:

```
--dns-addr <value>   redirect UDPv4 DNS requests to the supplied IPv4 address (experimental)
--dns-port <value>   redirect UDPv4 DNS requests to the supplied port (53 by default)
```

Yani bu, **Windows'un DNS ayarini degistirmiyor**; WinDivert ile UDP 53
DNS paketlerini yakalayip Yandex DNS'e (77.88.8.8, port 1253) yeniden
yonlendiriyor. README'de belirtilen "ISS'lerin DNS degisikligine izin
vermemesi" sorununu bu sekilde asiyor. Ancak bu hala **DNS trafigine
mudahale** demektir - sadece isletim sistemi ayarina dokunmuyor. Diger
alternatif script'lerde (`alternative2`, `alternative6`) `--dns-addr`
kullanilmiyor; o durumlarda kullanicinin Windows DNS ayarini elle
degistirmesi gerektigi README'de acikca yaziyor.

Tum varyantlar (`turkey_dnsredir_alternative*_superonline.cmd`):

| Dosya | Komut |
|---|---|
| ana (`turkey_dnsredir.cmd`) | `-5 --set-ttl 5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr ... --dnsv6-port 1253` |
| alternative_superonline | `--set-ttl 3` |
| alternative2_superonline | `-5` (baska hicbir sey yok) |
| alternative3_superonline | `--set-ttl 3 --dns-addr 77.88.8.8 --dns-port 1253 ...` |
| alternative4_superonline | `-5 --dns-addr 77.88.8.8 --dns-port 1253 ...` |
| alternative5_superonline | `-9 --dns-addr 77.88.8.8 --dns-port 1253 ...` |
| alternative6_superonline | `-9` (baska hicbir sey yok) |

`-9` on tanimli setinin gercek karsiligi (goodbyedpi.exe'nin varsayilani):

```
-9   -f 2 -e 2 --wrong-seq --wrong-chksum --reverse-frag --max-payload -q
```

Servis kurulumu (`service_install_dnsredir_turkey.cmd`) `sc create` ile
ana profili birebir hizmet olarak kaydediyor, `start= auto` ile.
`service_remove.cmd` hem `GoodbyeDPI` servisini hem de WinDivert'in
kendi kaydettigi `WinDivert`/`WinDivert14` servislerini siliyor.

## 2. Sizin calisan Zapret profilinizde kullanilan sey

`baslat.bat` uzerinden dogrulanmis 3 profil (winws.exe'nin gomulu yardim
metniyle karsilastirilarak tum parametreler dogrulanmistir - `--dpi-desync`,
`--dpi-desync-split-pos`, `--dpi-desync-autottl`, `--dpi-desync-skip-nosni`,
`--dpi-desync-start`, `--dpi-desync-cutoff`, `--dpi-desync-repeats` gercek
ve gecerli winws.exe parametreleridir):

- **HOSTFAKESPLIT**: `--dpi-desync=hostfakesplit --dpi-desync-split-pos=sld ...`
- **FAKE**: `--dpi-desync=fake ...`
- **MULTISPLIT**: `--dpi-desync=multisplit --dpi-desync-split-pos=method,host ...`

Uctu de yalnizca `--wf-tcp=443` filtresiyle calisiyor - UDP/QUIC'e hic
dokunmuyor, DNS ile ilgili hicbir parametre (`--dns-*`, `--hostlist` vb.)
kullanmiyor. Bu, GoodbyeDPI'nin `--dns-addr` yaklasiminin tam tersi bir
tasarim tercihi: Zapret tarafinda DNS trafigine hicbir sekilde
mudahale edilmiyor.

## 3. Fark

| | GoodbyeDPI Turkey | Sizin Zapret profiliniz |
|---|---|---|
| Calisma katmani | WinDivert (goodbyedpi.exe) | WinDivert (winws.exe) - farkli motor, ayni surucu tipi |
| Hedef trafik | TCP (HTTP/HTTPS fragmentasyon+fake) + opsiyonel UDP DNS yonlendirme | Yalnizca TCP/443 |
| DNS | Ana profilde UDP DNS sorgularini Yandex DNS'e yonlendiriyor (deneysel, WinDivert uzerinden) | Hic dokunmuyor |
| TTL stratejisi | Sabit `--set-ttl` veya `--auto-ttl` (preset icinde) | `--dpi-desync-autottl=1:4-10` (otomatik, sinirli araliktakiler) |
| Yontem | Fragmentasyon + ters siralama + (opsiyonel) checksum/seq bozma | SNI/host/method konumuna gore bolme (split) + fake paket |
| Profil cesitliligi | 7 hazir varyant, ISS bazli deil ama "superonline" etiketli | 3 profil (stable/compatibility/strong), genel amacli |
| Servis kurulumu | Var, `sc create` ile | Yoktu (bu projeyle eklendi) |

**Dogrudan bire-bir parametre karsiligi yok.** GoodbyeDPI'nin
`-f`/`-e` (fragment boyutu) ve `--reverse-frag` mantigi ile Zapret'in
`--dpi-desync=hostfakesplit/fake/multisplit` + `--dpi-desync-split-pos`
mantigi farkli motorlarin farkli birimleridir; birini digerine ceviren
otomatik bir esleme yoktur. Bu yuzden bu projede GoodbyeDPI parametreleri
Zapret'e "cevrilmemis", sizin zaten dogrulanmis calisan Zapret
profilleriniz oldugu gibi korunmustur.

## 4. Turkiye geneli icin onerilen mimari

Bu projede (ZapretTurkey) su karar alinmistir:

1. Motor olarak yalnizca **winws.exe (Zapret)** kullanilir; GoodbyeDPI
   dahil edilmez. Ikisi ayni WinDivert surucusunu farkli sekilde
   kullandigi icin ayni anda calistirilmalari onerilmez (diagnostics.bat
   bunu kontrol eder).
2. Sizin calisan 3 profiliniz (stable/compatibility/strong) **degistirilmeden**
   `profiles/*.conf` altina tasindi - "Known Good" referans.
3. DNS varsayilan olarak degistirilmez (Zapret tarafinin zaten yaptigi gibi).
   Cloudflare DNS atama, GoodbyeDPI'nin degil, sizin kendi belirttiginiz
   "su an calisan kombinasyon" (Cloudflare + TCP stable) notundan yola
   cikilarak **opsiyonel** bir Ayarlar menusu maddesi olarak eklendi -
   varsayilan olarak KAPALI.
4. ISS bazli profil eslemesi (bolum 17) bu asamada **doldurulmamistir**;
   gercek olmayan veri uydurulmamasi icin `docs/ISS.md` bos bir sablon
   olarak birakildi ve GitHub Issue'lardan topluluk verisiyle
   doldurulmasi onerilir.
