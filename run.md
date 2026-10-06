# Lancer ITARA POS

Deux terminaux. L’interface web parle à l’API via le proxy Vite (`/api` et `/storage` vers `http://127.0.0.1:8001`).

Le port 8000 est déjà utilisé par une autre application sur cette machine. ITARA POS utilise donc 8001.

## API (Laravel)

```powershell
cd backend
php artisan serve --host=127.0.0.1 --port=8001
```

- API : http://127.0.0.1:8001

## Application web (Vue)

```powershell
cd frontend
npm run dev
```

- Application : http://127.0.0.1:4173

Première installation des dépendances :

```powershell
cd frontend
npm install
```

```powershell
cd backend
composer install
php artisan key:generate
php artisan migrate
```

## Site vitrine (optionnel)

```powershell
cd website
npm install
npm run dev
```

- Site : http://127.0.0.1:5174
