# Vertigo Games — Technical Artist Demo

scroll edilebilir Battle Pass ekranı ve bir silah VFX'i.
Unity 6000.0.73f1 URP ve 1920x1080 resolution'ında geliştirildi.

Projeyi açtıktan sonra iki adet sahne var:

- `Assets/_Project/Scenes/Scene_UI.unity` — Battle Pass Road (Task 1)
- `Assets/_Project/Scenes/Scene_WeaponVFX.unity` — Silah VFX (Task 2)

Play'e basman yeterli.

---

## Task 1 — Battle Pass Road

Yatay scroll eden, üstte premium / altta free olmak üzere çift sıralı season pass.
Her ödül kartının bir durumu var ve durumlar görsel olarak ayrışıyor:

- **Locked** — gri kart, üstünde kilit. Tıklanınca sadece küçük bir shake yapar.
- **Claimable** — parlayan kart, üstünde kayan shine + red dot. Tıklayınca claim olur.
- **Claimed** — claimed kart görseli + yeşil tik, claim anında bir feedback.
- **Premium kilitli** — level'a ulaşılmış ama premium pass alınmamış kart. Hem kilit hem claimable görünür ama pass alınmadan toplanamaz.

### Test edilecekler

- pass'i sağa-sola **scroll** et.
- Bir **claimable** karta tıkla → claim olur, claimed görseline geçer. feedback görünür.
- Bir **locked premium** karta tıkla → kart titrer ve soldaki **GET** butonu zıplar (tıklaman için yönlendirme).
- **GET** butonuna bas → premium açılır, claimable olur.
- Pass'in ortasındaki **buy** butonuna (gem) bas → bir sonraki level'a ilerler o anda yeni açılan ödüller pop yapar. Son level'a gelince buton kapanır.
- İki yandaki **label**'lar: sol label, geride bıraktığın sonraki level'ı gösterir; sağ label, ileride seni bekleyen değerli ödülü gösterir. (hangisine tıklarsan oraya kaydırır)

### Kısa teknik notlar

- UI sahneye elle kuruldu; durum geçişleri ve "pop / shake / claim" animasyonları **tamamen script** (coroutine tabanlı lerp) ile yapılıyor — Animator/AnimationClip yok, her şey koddan okunabilir.
- Arka plan UI shader'ı (`ScrollingTextureWithGlow`) — kayan hiyeroglif deseni + merkez glow + vignette hepsi prosedürel, ekran oranı shader içinde düzeltiliyor.
- Kullanılan tüm küçük UI sprite'ları tek bir **SpriteAtlas**'ta (ASTC, mobil) — draw call'ları optimize etmek için. Büyük/tek-kullanımlık görseller (karakter render'ı, full-screen glow) atlas dışında.
- Shine sadece claimable kartlarda aktif; scroll indikatörü her frame değil, yalnızca scroll ve level değişiminde güncelleniyor. optimizasyon için.

---

## Task 2 — Silah VFX

Silahı saran, namluya doğru akan "wind line" efekti + particle'lar.

### Test edilecekler

sahnede play'e basınca silah kendi etrafında yavaşça dönüyor. İstediğin an üzerine **basıp sürükleyerek** çevirebilirsin — bıraktığında flick yönünde momentumla bir süre döner, sonra duraksamadan o yönde otomatik dönmeye devam eder. Efekti her açıdan görmek için.

### Kısa teknik notlar

- wind lines, HLSL shader'ı (`WindLines`). Mesh'in UV'sini kullanıyor — Tek bir noise texture'ı U'yu zamanla kaydırıyor, çizgiler ve aura bu desenden geliyor. Ribbon vertex shader'da kendi normal'i yönünde sinüs dalgasıyla büküldüğü için noise UV'leri yerinde kalıyor.
- `half` precision, tek pass, additive
- sparkle'lar particle'ları additive.
- line rengi HDR; sahnedeki bloom ile parlıyor. referansta parıltı var diye yaptım mobil performans gözetilirse bloom ve hdr kapatılabilir.
