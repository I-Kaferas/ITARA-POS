# Lancer ITARA POS

Un terminal par application. L’interface web parle à l’API via le proxy Vite (`/api` et `/storage` vers `http://127.0.0.1:8001`).

Le port 8000 est déjà utilisé par une autre application sur cette machine. ITARA POS utilise donc **8001**.

| Application | URL |
|---|---|
| API Laravel | http://127.0.0.1:8001 |
| Web Vue (POS / admin) | http://127.0.0.1:4173 |
| Site vitrine | http://127.0.0.1:5174 |
| Analytics | http://127.0.0.1:5175 |
| Tableau de bord analytics | http://127.0.0.1:5180 |
| Reverb (temps réel cloud) | ws://127.0.0.1:8080 |
| PostgreSQL | 127.0.0.1:5432 |
| Redis | 127.0.0.1:6379 |
| MinIO (fichiers) | http://127.0.0.1:9000 (console http://127.0.0.1:9001) |
| Android POS | appareil ou émulateur (Flutter) |

---

## Tout lancer (web + Android)

Un terminal par script. Les laisser ouverts. L’ordre compte : base, puis API, puis files et temps réel, puis le web, puis Android.

**1. PostgreSQL, Redis, MinIO** (depuis la racine) :

```powershell
cd docker
docker compose up -d postgres redis minio
```

Ne pas lancer le service `app` de Compose : il prend le port **8000**, déjà utilisé par une autre application. L’API ITARA tourne avec `php artisan serve` sur **8001**.

**2. API** :

```powershell
cd backend
php artisan serve --host=127.0.0.1 --port=8001
```

Pour un téléphone Android sur le réseau local (pas l’émulateur), écouter toutes les interfaces à la place :

```powershell
cd backend
php artisan serve --host=0.0.0.0 --port=8001
```

**3. File d’attente** (Redis ; requis pour le temps réel) :

```powershell
cd backend
php artisan queue:work --sleep=3 --tries=3
```

**4. Temps réel** :

```powershell
cd backend
php artisan reverb:start --host=0.0.0.0 --port=8080
```

**5. Planificateur** (relance `realtime:flush` chaque minute) :

```powershell
cd backend
php artisan schedule:work
```

**6. Web POS / admin** :

```powershell
cd frontend
npm run dev
```

Ouvre http://127.0.0.1:4173. Le proxy Vite envoie `/api` et `/storage` vers `http://127.0.0.1:8001`.

**7. Android** :

```powershell
cd mobile
flutter devices
flutter run -d android
```

L’émulateur n’atteint pas `127.0.0.1` de la machine. Utiliser l’alias hôte :

```powershell
cd mobile
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1
```

Téléphone USB, API sur `127.0.0.1` (le défaut de l’app) :

```powershell
adb reverse tcp:8001 tcp:8001
cd mobile
flutter run -d android
```

Téléphone sur le Wi-Fi, API lancée avec `--host=0.0.0.0` (`<ip-du-pc>` = l’adresse IPv4 du PC) :

```powershell
cd mobile
flutter run -d android --dart-define=API_BASE_URL=http://<ip-du-pc>:8001/api/v1
```

Cibler un appareil précis (l’id vient de `flutter devices`) :

```powershell
cd mobile
flutter run -d <device-id>
```

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

## Analytics (optionnel)

```powershell
cd analytics
npm run dev
```

Première installation :

```powershell
cd analytics
npm install
```

---

## Tableau de bord analytics (optionnel)

```powershell
cd analytics-dashboard
npm run dev
```

Première installation :

```powershell
cd analytics-dashboard
npm install
```

Ouvre http://127.0.0.1:5180.

---

## Android POS (Flutter)

Depuis la racine du dépôt, dans `mobile`. Le détail des commandes (émulateur, `adb reverse`, Wi-Fi) est dans **Tout lancer** ci-dessus.

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

Émulateur (l’API hôte est `10.0.2.2`, pas `127.0.0.1`) :

```powershell
cd mobile
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1
```

Téléphone USB :

```powershell
adb reverse tcp:8001 tcp:8001
cd mobile
flutter run -d android
```

Téléphone Wi-Fi (`php artisan serve --host=0.0.0.0 --port=8001`) :

```powershell
cd mobile
flutter run -d android --dart-define=API_BASE_URL=http://<ip-du-pc>:8001/api/v1
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

1. Données : `docker compose up -d postgres redis minio` dans `docker`
2. API : `php artisan serve --host=127.0.0.1 --port=8001` dans `backend` (`0.0.0.0` si un téléphone Wi-Fi doit joindre l’API)
3. File : `php artisan queue:work --sleep=3 --tries=3` dans `backend`
4. Temps réel : `php artisan reverb:start --host=0.0.0.0 --port=8080` dans `backend`
5. Planificateur : `php artisan schedule:work` dans `backend`
6. Web : `npm run dev` dans `frontend` → http://127.0.0.1:4173
7. Android : `flutter run -d android` dans `mobile` (émulateur : `--dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1`)
