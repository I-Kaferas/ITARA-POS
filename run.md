# Lancer ITARA POS

Un terminal par application. L’interface web parle à l’API via le proxy Vite (`/api` et `/storage` vers `http://127.0.0.1:8001`).

Le port 8000 est déjà utilisé par une autre application sur cette machine. ITARA POS utilise donc **8001**.

| Application | URL |
|---|---|
| API Laravel | http://127.0.0.1:8001 |
| Web Vue (POS / admin) | http://127.0.0.1:4173 |
| Site vitrine | http://127.0.0.1:5174 |
| Reverb (temps réel cloud) | ws://127.0.0.1:8080 |
| Android POS | appareil ou émulateur (Flutter) |

---

## API (Laravel)

```powershell
cd backend
php artisan serve --host=127.0.0.1 --port=8001
```

Temps réel cloud (optionnel, un autre terminal) :

```powershell
cd backend
php artisan reverb:start --host=0.0.0.0 --port=8080
```

File d’attente (optionnel) :

```powershell
cd backend
php artisan queue:work --sleep=3 --tries=3
```

Planificateur (optionnel) :

```powershell
cd backend
php artisan schedule:work
```

Première installation :

```powershell
cd backend
copy .env.example .env
composer install
php artisan key:generate
php artisan migrate
```

---

## Application web (Vue)

```powershell
cd frontend
npm run dev
```

Première installation :

```powershell
cd frontend
copy .env.example .env
npm install
```

Build de production :

```powershell
cd frontend
npm run build
npm run preview
```

---

## Site vitrine (optionnel)

```powershell
cd website
npm run dev
```

Première installation :

```powershell
cd website
npm install
```

---

## Android POS (Flutter)

Depuis la racine du dépôt, dans `mobile`.

Liste des appareils :

```powershell
cd mobile
flutter devices
```

Lancer sur un téléphone ou un émulateur Android :

```powershell
cd mobile
flutter run -d android
```

Cibler un appareil précis (l’id vient de `flutter devices`) :

```powershell
cd mobile
flutter run -d <device-id>
```

Windows POS (même projet Flutter) :

```powershell
cd mobile
flutter run -d windows
```

Première installation :

```powershell
cd mobile
flutter pub get
```

APK de debug :

```powershell
cd mobile
flutter build apk --debug
```

Le terminal Master expose aussi une API locale sur le port **8001** du réseau LAN (`http://<ip-du-master>:8001/api/v1`). Un Slave s’y connecte après appairage. Ne lancez pas `php artisan serve` et un Master Flutter sur le même port en même temps.

---

## Ordre de démarrage

1. API : `php artisan serve --host=127.0.0.1 --port=8001`
2. Web : `npm run dev` dans `frontend`
3. Android : `flutter run -d android` dans `mobile` (API cloud déjà joignable, ou Master local si le terminal est le Master)
