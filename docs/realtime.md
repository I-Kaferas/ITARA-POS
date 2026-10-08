# Temps réel

Les écrans reçoivent les changements des autres postes par WebSocket. La base de données reste la source de vérité. Le socket ne fait que propager un signal court. Les écrans rechargent ensuite la ressource concernée (vente, stock, tableau de bord, plan de salle).

```text
Action Vue
  → API Laravel
  → transaction
  → ligne realtime_outbox
  → COMMIT
  → file Redis
  → Laravel Reverb
  → Laravel Echo
  → Pinia
  → écran
```

Si la transaction est annulée, la ligne d’outbox disparaît avec elle et aucun événement n’est envoyé.

## Configuration

Backend (`backend/.env`) :

```text
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=
REVERB_APP_KEY=
REVERB_APP_SECRET=
REVERB_HOST=localhost
REVERB_PORT=8080
REVERB_SCHEME=http
QUEUE_CONNECTION=redis
REALTIME_QUEUE=default
```

En production, `REVERB_SCHEME=https` et le proxy Nginx expose `wss`. Si `REALTIME_QUEUE=realtime`, le worker doit écouter cette file :

```text
php artisan queue:work --queue=realtime,default
php artisan reverb:start
php artisan schedule:work
```

`schedule:work` relance chaque minute `realtime:flush`, qui renvoie les événements stockés mais pas encore diffusés.

Frontend (`frontend/.env`) :

```text
VITE_REVERB_APP_KEY=
VITE_REVERB_HOST=
VITE_REVERB_PORT=8080
VITE_REVERB_SCHEME=http
```

Aucune clé, hôte ou secret n’est écrit dans le code.

## Canaux

| Canal | Qui peut s’abonner |
| --- | --- |
| `private-tenant.{tenantId}` | Utilisateur actif de ce tenant |
| `private-tenant.{tenantId}.store.{storeId}` | Même règle, et magasin assigné si l’utilisateur a des magasins |
| `presence-tenant.{tenantId}.online` | Même règle que le canal tenant. Expose seulement l’id et le nom |

Un utilisateur du tenant A ne peut pas s’abonner au tenant B. L’autorisation est faite dans `routes/channels.php`.

## Événements

Le nom diffusé est le nom métier (`sale.created`, `stock.updated`, …). Le corps ne contient pas le modèle complet.

| Événement | Producteur | Consommateurs |
| --- | --- | --- |
| `sale.created` / `sale.updated` / `sale.completed` / `sale.cancelled` | `SaleObserver` | POS, commandes, tableau de bord |
| `sale.item_added` / `sale.item_removed` | `SaleItemObserver` | POS |
| `payment.created` / `payment.completed` | paiements | POS, tableau de bord |
| `stock.updated` | mouvement de stock | POS, stock, tableau de bord |
| `stock.low` | alerte de stock | stock, tableau de bord |
| `table.occupied` / `table.available` / `table.reserved` | `PosTableObserver` | plan de salle |
| `product.created` / `product.updated` / `product.price.changed` | `ProductObserver` | POS |
| `purchase.created` / `purchase.updated` / `purchase.status.changed` / `purchase.received` | `PurchaseOrderObserver`, réception | achats |
| `expense.created` / `expense.updated` | `ExpenseObserver` | dépenses, tableau de bord |
| `shift.opened` / `shift.closed` / `shift.updated` | `CashierShiftObserver` | caisse |
| `cash.movement.created` | `CashMovementObserver` | caisse |
| `category.created` / `category.updated` | `CategoryObserver` | catalogue, POS |
| `unit.created` / `unit.updated` | `UnitObserver` | catalogue, POS |
| `sale.refunded` | retour de vente | POS, stock, tableau de bord |
| `kitchen.new` / `kitchen.sent` | commande envoyée en cuisine | restaurant, cuisine, notifications |
| `kitchen.ready` | ticket prêt | cuisine, restaurant, notifications |
| `kitchen.updated` | ticket en préparation ou servi | cuisine, restaurant |
| `order.created` / `order.updated` | addition restaurant créée / modifiée | restaurant |
| `notification.created` | notification inbox | cloche, tableau de bord |
| `device.connected` / `device.disconnected` | appareil POS enregistré / révoqué | POS, appareils |
| `hotel.reservation.created` | réservation hôtel créée | hôtel, tableau de bord hôtel, notifications |
| `hotel.reservation.updated` | réservation hôtel modifiée | hôtel |
| `hotel.room.updated` | statut de chambre modifié | hôtel |
| `pos.reservation.created` / `pos.reservation.updated` | réservation de table | plan de salle, réservations POS |
| `stay.signed` | signature de séjour | séjour |

Le tableau de bord ne se recharge que lorsqu’un chiffre affiché change (vente terminée, stock, dépense, caisse). Une ligne ajoutée au ticket ne relance pas les statistiques. Le catalogue du POS se recharge en silence sur un changement de stock ou de prix ; une vente ne recharge que les tickets en attente. Les listes hôtel et cuisine se mettent à jour sans réafficher l’écran de chargement. La cloche de notifications se met à jour à l’arrivée de l’événement. Elle n’interroge le serveur en boucle que lorsque le socket est coupé.

Chaque événement a un `event_id`. Le client ignore un identifiant déjà traité.

## Reconnexion

L’indicateur en haut de l’écran affiche connecté, reconnexion ou hors ligne. Au retour du socket, le client appelle `GET /api/v1/realtime/sync?since=…` et applique les événements manqués. Si le socket est coupé, le même appel est répété toutes les 30 secondes. Il n’y a pas de sondage tant que le socket est connecté.

Le stock vendu simultanément par plusieurs caisses est protégé par des verrous de ligne dans `StockBalanceService` et `SaleEngine`, pas par le WebSocket.

## Réseau local (Master ↔ Slaves)

Sans Internet, le Master Flutter expose un hub WebSocket `ws://{master}:8001/api/v1/realtime`. Les esclaves s’y connectent après appairage. Les événements LAN utilisent les noms PascalCase du prompt (§36) : `NewSale`, `SaleUpdated`, `PaymentReceived`, `StockUpdated`, `TableUpdated`, `OrderCreated`, `OrderUpdated`, `KitchenOrderCreated`, `KitchenOrderReady`, `NotificationCreated`, `DeviceConnected`, `DeviceDisconnected`. Ce canal ne dépend pas de Reverb ni du cloud.

## Santé

`GET /api/v1/health` indique l’état de l’application, de la base, de Redis, de la file et de la configuration Reverb.

## Dépannage

- L’indicateur reste gris : vérifier `VITE_REVERB_APP_KEY`, le jeton, et que `php artisan reverb:start` tourne.
- Les événements sont en base (`realtime_outbox.broadcast_at` vide) : le worker de file ne tourne pas, ou Reverb est injoignable. `php artisan realtime:flush` renvoie les événements récents.
- Un écran ne bouge pas : il doit appeler `useRealtimeSync` avec le type d’événement concerné.
