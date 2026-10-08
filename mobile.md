# ITARA POS — MASTER DEVELOPMENT PROMPT

## Flutter Android + Flutter Windows + Flutter BLoC + Offline-First + Master/Slave + Local Network + Printer Management + ITARA ERP

---

# 1. VISION DU PROJET

Construire **ITARA POS**, un système de point de vente professionnel, distribué et multi-plateforme destiné à fonctionner avec l'écosystème **ITARA ERP**.

L'application doit être développée avec :

* Flutter
* Dart
* Flutter BLoC
* Clean Architecture
* Repository Pattern
* SQLite local
* REST API
* WebSockets / Laravel Reverb
* Offline-First Architecture
* Local Network
* Master/Slave Architecture
* Automatic Device Discovery
* Printer Management
* Synchronization Engine

Les plateformes principales sont :

1. **Android POS**
2. **Windows POS**
3. **Android Tablet Kitchen Display**
4. **Master POS / Local Edge Server**

---

# 2. RÈGLE ABSOLUE

NE PAS transformer l'application Web existante en application mobile ou Windows.

NE PAS utiliser WebView.

Créer une **véritable application Flutter native**.

L'application Web Laravel/Vue.js reste l'ERP central.

Flutter devient le terminal POS.

Architecture globale :

```text
                    ITARA ERP CLOUD
                         │
                    Laravel API
                         │
                  Laravel Reverb
                         │
                    INTERNET
                         │
                         ▼
              ┌─────────────────────┐
              │    MASTER POS       │
              │                     │
              │ Flutter             │
              │ SQLite              │
              │ Local API           │
              │ Sync Engine         │
              │ Discovery           │
              │ Printer Manager     │
              │ Device Manager      │
              └──────────┬──────────┘
                         │
                    LOCAL NETWORK
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
     Android POS    Windows POS    Kitchen Display
       Slave           Slave
          │              │
          └──────────────┼──────────────┘
                         │
                         ▼
                    LOCAL PRINTERS
```

---

# 3. PHILOSOPHIE OFFLINE-FIRST

Le système doit être conçu avec cette priorité :

```text
LOCAL DATA
    ↓
LOCAL NETWORK
    ↓
MASTER
    ↓
CLOUD
```

et jamais :

```text
POS
 ↓
Internet
 ↓
Cloud
```

pour une opération qui peut être réalisée localement.

---

# 4. LES TROIS NIVEAUX DE FONCTIONNEMENT

## MODE A — FULL ONLINE

```text
POS
 ↓
MASTER
 ↓
ITARA ERP
```

Tout est synchronisé.

---

## MODE B — LOCAL OFFLINE

Internet indisponible :

```text
POS
 ↓
MASTER
 ↓
LOCAL DATABASE
```

Le commerce continue de fonctionner.

---

## MODE C — ISOLATED OFFLINE

Le Slave perd le Master :

```text
POS SLAVE
 ↓
LOCAL SQLITE
 ↓
OFFLINE QUEUE
```

Le POS continue les opérations autorisées.

Lorsque le Master revient :

```text
Slave
 ↓
Sync Queue
 ↓
Master
 ↓
Cloud
```

---

# 5. ARCHITECTURE MASTER / SLAVE

## MASTER

Le Master est le **Edge Server local du commerce**.

Il centralise :

* base locale principale ;
* API locale ;
* synchronisation ;
* appareils ;
* imprimantes ;
* configuration ;
* réseau ;
* commandes ;
* stock ;
* ventes ;
* clients ;
* restaurant ;
* cuisine ;
* realtime local.

Le Master doit continuer à fonctionner sans Internet.

---

## SLAVE

Le Slave est un terminal POS connecté au Master.

Il possède :

* SQLite local ;
* cache ;
* BLoC ;
* queue offline ;
* synchronisation ;
* configuration locale.

Le Slave doit pouvoir fonctionner temporairement même si le Master est indisponible.

---

# 6. MASTER DISCOVERY

Lorsqu'un POS démarre pour la première fois :

```text
Searching for ITARA Master...
```

Il doit rechercher automatiquement les Masters présents sur le réseau local.

Utiliser :

### mDNS / DNS-SD

Service :

```text
_itara-pos._tcp
```

Exemple :

```text
ITARA-POS-MASTER.local
```

### UDP Discovery

Prévoir également UDP Broadcast pour les réseaux où mDNS n'est pas disponible ou fiable.

---

# 7. MASTER DISCOVERY RESPONSE

Le Master répond avec :

```json
{
  "type": "ITARA_MASTER_RESPONSE",
  "master_id": "master-001",
  "name": "ITARA POS Gitega",
  "ip": "192.168.1.10",
  "port": 8765,
  "tenant_id": "...",
  "branch_id": "...",
  "version": "1.0.0"
}
```

Le Slave affiche :

```text
Masters found

ITARA POS — Gitega
192.168.1.10

● Online

[ CONNECT ]
```

---

# 8. SECURE PAIRING

La découverte ne signifie pas automatiquement autorisation.

Processus :

```text
DISCOVERY
 ↓
HANDSHAKE
 ↓
AUTHENTICATION
 ↓
PAIRING
 ↓
AUTHORIZATION
 ↓
REGISTER DEVICE
```

Méthodes possibles :

* code à 6 chiffres ;
* QR Code ;
* approbation depuis le Master.

Exemple :

```text
POS-ANDROID-004 wants to connect.

Code: 739421

[ ACCEPT ]
[ REJECT ]
```

---

# 9. DEVICE REGISTRY

Le Master doit maintenir une liste des appareils :

```text
Devices

POS-01       Android      🟢
POS-02       Android      🟢
POS-03       Windows      🟡
Kitchen-01   Android      🟢
```

Informations :

* device ID ;
* device name ;
* type ;
* OS ;
* IP ;
* tenant ;
* branch ;
* user ;
* role ;
* version ;
* last seen ;
* status.

---

# 10. HEARTBEAT

Chaque terminal envoie régulièrement un heartbeat.

```text
Slave
 ↓
Heartbeat
 ↓
Master
```

Statuts :

```text
ONLINE
IDLE
OFFLINE
SYNCING
ERROR
BLOCKED
```

Si le heartbeat disparaît :

```text
ONLINE
 ↓
TIMEOUT
 ↓
OFFLINE
```

---

# 11. RECONNEXION AUTOMATIQUE

Lorsqu'une connexion est perdue :

```text
Connection Lost
 ↓
Search Master
 ↓
Master Found
 ↓
Reconnect
 ↓
Authenticate
 ↓
Sync
 ↓
Connected
```

Aucun redémarrage manuel ne doit être nécessaire.

---

# 12. LOCAL MASTER API

Le Master expose une API locale :

```text
http://192.168.1.10:8765
```

Endpoints :

```text
/discovery
/pair
/auth
/health
/products
/categories
/customers
/sales
/payments
/orders
/tables
/kitchen
/inventory
/sync
/devices
/printers
/settings
```

Cette API est destinée aux terminaux du réseau local.

---

# 13. SQLITE

Tous les terminaux doivent disposer d'une base locale.

Le Master possède la base locale principale.

Les Slaves possèdent un cache local permettant le fonctionnement offline.

Prévoir :

```text
SQLite
Repositories
DAO
Transactions
Indexes
Migrations
```

---

# 14. DATA MODEL

Créer notamment :

```text
Tenant
Organization
Branch
Terminal
Device
User
Role
Permission

Product
Category
Unit
UnitConversion
ProductPrice

Customer
Supplier

Cart
CartItem

Sale
SaleItem
Payment
Refund

CashRegister
CashMovement
Shift

Stock
StockMovement
StockCount

Purchase
PurchaseItem

Expense

RestaurantTable
RestaurantOrder
RestaurantOrderItem
KitchenTicket
Modifier
Extra

Printer
PrinterGroup
PrinterRoute
PrintJob

SyncJob
SyncOutbox
SyncConflict

Notification
AuditLog
```

---

# 15. CLEAN ARCHITECTURE

Structure :

```text
lib/

core/
 ├── config/
 ├── constants/
 ├── database/
 ├── network/
 ├── security/
 ├── storage/
 ├── sync/
 ├── realtime/
 ├── printer/
 ├── discovery/
 ├── permissions/
 ├── logging/
 └── theme/

features/

 ├── authentication/
 ├── dashboard/
 ├── pos/
 ├── products/
 ├── categories/
 ├── customers/
 ├── inventory/
 ├── purchases/
 ├── suppliers/
 ├── restaurant/
 ├── tables/
 ├── kitchen/
 ├── sales/
 ├── payments/
 ├── cash_register/
 ├── shifts/
 ├── expenses/
 ├── printers/
 ├── devices/
 ├── synchronization/
 ├── reports/
 ├── notifications/
 └── settings/
```

Chaque feature :

```text
data/
domain/
presentation/
```

---

# 16. FLUTTER BLOC

Utiliser réellement Flutter BLoC.

Créer notamment :

```text
AuthenticationBloc

DashboardBloc

ProductBloc
CategoryBloc

CartBloc
CheckoutBloc
PaymentBloc

CustomerBloc

InventoryBloc
StockCountBloc

PurchaseBloc
SupplierBloc

CashRegisterBloc
ShiftBloc

SalesBloc
RefundBloc

ExpenseBloc

RestaurantBloc
TableBloc
RestaurantOrderBloc
KitchenBloc

MasterDiscoveryBloc
MasterConnectionBloc
MasterPairingBloc

NetworkBloc
DeviceBloc

PrinterDiscoveryBloc
PrinterConnectionBloc
PrinterConfigurationBloc
PrinterRoutingBloc
PrintQueueBloc

LocalSyncBloc
CloudSyncBloc
ConflictResolutionBloc

NotificationBloc

TerminalBloc
SettingsBloc
```

Aucune logique métier importante dans les widgets.

---

# 17. NETWORK STATE

Créer un état réseau global :

```text
NO_NETWORK
LOCAL_NETWORK_ONLY
MASTER_CONNECTED
INTERNET_CONNECTED
FULLY_ONLINE
```

L'application doit savoir :

```text
CanSell?
CanSyncMaster?
CanSyncCloud?
CanPrint?
CanUseKitchen?
```

---

# 18. POS ANDROID

Créer une vraie application Android Flutter.

Optimiser pour :

* smartphones ;
* tablettes ;
* écrans tactiles ;
* petits écrans ;
* appareils peu puissants.

Navigation smartphone :

```text
POS
Sales
Tables
Stock
Menu
```

Tablette :

```text
Sidebar
+
Product Grid
+
Cart
```

---

# 19. POS WINDOWS

Créer une vraie application Windows Flutter.

Optimiser pour :

* écran large ;
* clavier ;
* souris ;
* scanner ;
* imprimante ;
* tiroir-caisse.

Supporter les raccourcis :

```text
F1 Search
F2 New Sale
F3 Customer
F4 Payment
F5 Hold
F6 Retrieve
ESC Cancel
```

---

# 20. POS PRINCIPAL

Le POS doit permettre :

* recherche ;
* catégories ;
* favoris ;
* produits rapides ;
* scan ;
* panier ;
* quantité ;
* remise ;
* taxe ;
* client ;
* commentaire ;
* hold ;
* reprise ;
* paiement ;
* annulation.

---

# 21. BARCODE

Supporter :

* EAN-13 ;
* EAN-8 ;
* UPC ;
* Code 128 ;
* QR Code.

Workflow :

```text
SCAN
 ↓
PRODUCT FOUND
 ↓
ADD TO CART
```

Si produit inconnu :

```text
Product not found
```

---

# 22. UNITÉS ET CONVERSIONS

Supporter :

```text
Piece
Bottle
Glass
Cup
Kg
Gram
Liter
ML
Meter
Box
Carton
Pack
```

Exemple :

```text
1 bottle = 750ml

750ml
250ml
150ml
```

Les mouvements de stock doivent respecter les conversions.

---

# 23. RESTAURANT

Supporter :

* tables ;
* zones ;
* commandes ;
* serveurs ;
* cuisine ;
* extras ;
* modifiers ;
* accompagnements ;
* split ;
* merge ;
* transfert.

Statuts :

```text
FREE
OCCUPIED
ORDERING
PREPARING
READY
SERVED
PAYING
CLOSED
```

---

# 24. KITCHEN DISPLAY

Kitchen Display Android/Tablet.

Statuts :

```text
NEW
PREPARING
READY
SERVED
CANCELLED
```

Les commandes doivent arriver en realtime.

---

# 25. PAIEMENT

Méthodes :

```text
Cash
Mobile Money
Card
Bank
Credit
Mixed Payment
```

Supporter plusieurs moyens de paiement pour une même vente.

---

# 26. CASH REGISTER

Fonctions :

```text
Open Register
Close Register
Cash In
Cash Out
Cash Adjustment
Cash Count
Reconciliation
```

Afficher :

```text
Expected Cash
Actual Cash
Difference
```

---

# 27. SHIFTS

Chaque shift doit être lié à :

* utilisateur ;
* terminal ;
* caisse ;
* branch ;
* date ;
* heure.

---

# 28. SALES / REFUNDS

Supporter :

* ventes ;
* historique ;
* vente suspendue ;
* annulation ;
* retour ;
* remboursement partiel ;
* remboursement total ;
* échange.

Les opérations sensibles doivent nécessiter les permissions appropriées.

---

# 29. INVENTORY

Supporter :

```text
Stock In
Stock Out
Transfer
Adjustment
Waste
Stock Count
Cycle Count
Verification
```

Le stock doit être basé sur les mouvements et non simplement sur des écrasements de quantité.

---

# 30. OFFLINE QUEUE

Créer une Outbox locale :

```text
sync_outbox
```

Champs :

```text
id
entity
entity_id
operation
payload
created_at
status
retry_count
last_error
```

Statuts :

```text
PENDING
SYNCING
SYNCED
FAILED
CONFLICT
```

---

# 31. IDEMPOTENCE

Chaque transaction possède :

```text
UUID
Transaction ID
Idempotency Key
```

Si une requête arrive deux fois :

```text
Already processed
→ Do not duplicate
```

Aucune vente ne doit être créée deux fois.

---

# 32. CONFLICT RESOLUTION

Créer un moteur de résolution des conflits.

Pour les ventes :

```text
Never overwrite completed sales.
```

Pour le stock :

```text
Use stock movements.
```

Pour les configurations :

```text
Master configuration wins.
```

Les règles doivent être configurables par domaine.

---

# 33. MASTER → SLAVE SYNC

Synchroniser :

```text
Products
Categories
Prices
Customers
Users
Permissions
Taxes
Tables
Restaurant Configuration
Printers
Printer Routing
```

---

# 34. SLAVE → MASTER SYNC

Synchroniser :

```text
Sales
Payments
Orders
Stock Movements
Expenses
Customers
Cash Movements
Shifts
```

---

# 35. MASTER → CLOUD

Le Master synchronise avec ITARA ERP :

```text
Master
 ↓
Cloud Sync Engine
 ↓
Laravel API
```

Synchroniser :

* ventes ;
* paiements ;
* stocks ;
* produits ;
* clients ;
* commandes ;
* dépenses ;
* utilisateurs ;
* configuration ;
* audit logs.

---

# 36. REALTIME

Utiliser :

```text
Laravel Reverb
WebSockets
```

Événements :

```text
NewSale
SaleUpdated
PaymentReceived
StockUpdated
TableUpdated
OrderCreated
OrderUpdated
KitchenOrderCreated
KitchenOrderReady
NotificationCreated
DeviceConnected
DeviceDisconnected
```

Le réseau local doit également pouvoir fournir du realtime entre Master et Slaves sans dépendre du cloud.

---

# 37. PRINTER MANAGEMENT

Créer un véritable système de gestion des imprimantes.

Supporter :

```text
USB
LAN
Ethernet
Wi-Fi
Bluetooth
```

Créer :

```text
PrinterService
PrinterConnection
PrinterManager
PrintQueue
PrinterRouter
```

---

# 38. PRINTER DISCOVERY

Le Master doit pouvoir rechercher les imprimantes du réseau.

Exemple :

```text
Searching printers...

EPSON TM-T20III
192.168.1.50
Port 9100

[ ADD ]
```

Prévoir également la configuration manuelle :

```text
Printer Name
IP
Port
Type
Paper Width
```

---

# 39. PRINTER GROUPS

Créer :

```text
Kitchen
Bar
Cashier
Reception
Warehouse
Dessert
```

Chaque groupe peut contenir plusieurs imprimantes.

---

# 40. PRINTER ROUTING

Exemple :

```text
Drink
 ↓
Bar Printer

Pizza
 ↓
Kitchen Printer

Receipt
 ↓
Cashier Printer
```

Possibilité de définir :

```text
Category → Printer
Product → Printer
Document → Printer
```

---

# 41. PRINTER FAILOVER

Si une imprimante tombe :

```text
Printer 1
   ↓
OFFLINE
   ↓
Printer 2
   ↓
PRINT
```

La vente ne doit jamais être annulée à cause d'une erreur d'impression.

---

# 42. PRINT QUEUE

Créer :

```text
PENDING
PRINTING
PRINTED
FAILED
RETRYING
```

Une impression échouée doit être conservée et réessayée.

---

# 43. MASTER PRINT SERVER

Le Master doit pouvoir centraliser les impressions :

```text
POS 01 ─┐
POS 02 ─┼──→ MASTER ──→ PRINTER
POS 03 ─┘
```

Ainsi, un seul réseau local peut partager les imprimantes entre plusieurs POS.

---

# 44. MASTER CONFIGURATION CENTER

Créer une interface dédiée :

```text
Master Configuration

General
Network
Devices
Printers
Printer Groups
Printer Routing
POS
Restaurant
Kitchen
Taxes
Payments
Synchronization
Security
Backup
```

---

# 45. DEVICE MANAGEMENT

Depuis le Master :

```text
Devices

POS-01
POS-02
POS-03
Kitchen-01
```

Actions :

```text
View
Rename
Disable
Remove
Sync
Reconnect
Send Configuration
```

---

# 46. NETWORK DIAGNOSTICS

Créer :

```text
Network Diagnostics

Internet          🟢
Local Network     🟢
Master            🟢
Cloud ERP         🟢
Database          🟢
Synchronization   🟢
Printer           🟢
```

Actions :

```text
Test Network
Test Master
Test Cloud
Test Printer
Force Sync
```

---

# 47. MASTER SETUP WIZARD

Premier lancement :

```text
Welcome to ITARA POS

[ CREATE MASTER ]
[ CONNECT TO MASTER ]
```

CREATE MASTER :

```text
Business
 ↓
Branch
 ↓
Master Name
 ↓
Local Network
 ↓
Database
 ↓
Printers
 ↓
Pair Devices
 ↓
Complete
```

---

# 48. SLAVE SETUP WIZARD

```text
Welcome

Searching for Master...

ITARA POS — Gitega
192.168.1.10

[ CONNECT ]
```

Puis :

```text
Scan QR
ou
Pairing Code
```

Puis :

```text
Device Name
POS-04

Role
Cashier

[ COMPLETE ]
```

---

# 49. SECURITY

Implémenter :

* HTTPS pour cloud ;
* authentification locale sécurisée ;
* pairing sécurisé ;
* tokens ;
* secure storage ;
* PIN ;
* biométrie ;
* auto-lock ;
* permissions ;
* audit ;
* chiffrement des données sensibles ;
* validation des payloads ;
* device authorization.

Le Master local ne doit pas exposer son API inutilement à Internet.

---

# 50. MULTI-TENANT

Architecture :

```text
Tenant
 ↓
Organization
 ↓
Branch
 ↓
Master
 ↓
Terminal
 ↓
User
```

Aucune donnée d'un tenant ne doit être accessible à un autre tenant.

---

# 51. MULTI-BRANCH

Permettre :

```text
ITARA Restaurant

Bujumbura
Gitega
Ngozi
```

Un utilisateur peut changer de branche uniquement si ses permissions le permettent.

---

# 52. MULTI-LANGUAGE

Préparer :

```text
Français
English
Kirundi
Swahili
```

Aucun texte hardcodé dans les widgets.

---

# 53. MULTI-CURRENCY

Préparer :

```text
BIF
USD
EUR
KES
TZS
```

Le taux de change doit venir du backend.

---

# 54. UI / UX

L'interface doit être :

* premium ;
* moderne ;
* claire ;
* rapide ;
* tactile ;
* professionnelle ;
* cohérente ;
* responsive.

Créer un Design System :

```text
AppColors
AppTypography
AppSpacing
AppRadius
AppShadows
AppButtons
AppInputs
AppCards
AppDialogs
```

Prévoir :

* Light Mode ;
* Dark Mode ;
* System Mode ;
* animations légères ;
* micro-interactions ;
* skeleton loading ;
* empty states ;
* error states.

---

# 55. PERFORMANCE

Priorité absolue :

```text
FAST
RELIABLE
OFFLINE
```

Optimiser :

* recherche locale ;
* SQLite ;
* cache ;
* pagination ;
* debounce ;
* lazy loading ;
* index database ;
* isolates si nécessaire.

Aucun appel réseau ne doit bloquer l'interface.

---

# 56. ERROR HANDLING

Créer :

```text
NetworkError
AuthenticationError
ValidationError
DatabaseError
SyncError
PrinterError
PermissionError
MasterConnectionError
DiscoveryError
PairingError
```

Les messages utilisateur doivent être compréhensibles.

Exemple :

```text
Connexion Internet indisponible.
La vente est enregistrée localement et sera synchronisée automatiquement.
```

---

# 57. LOGGING

Créer des logs :

```text
INFO
WARNING
ERROR
SYNC
NETWORK
PRINTER
DATABASE
SECURITY
DISCOVERY
PAIRING
```

Créer un système de diagnostic exportable pour le support ITARA.

---

# 58. AUDIT TRAIL

Tracer :

```text
User
Device
Action
Entity
Entity ID
Before
After
Timestamp
```

Actions sensibles :

```text
Discount
Refund
Cancel Sale
Stock Adjustment
Cash Adjustment
Price Change
Product Change
Printer Configuration
Device Pairing
Device Removal
```

---

# 59. REPORTS

Le POS peut afficher :

* ventes du jour ;
* ventes par utilisateur ;
* ventes par terminal ;
* ventes par produit ;
* ventes par méthode de paiement ;
* caisse ;
* dépenses ;
* stock faible ;
* rapports restaurant.

Les rapports lourds peuvent être calculés côté ERP.

---

# 60. GLOBAL SEARCH

Recherche locale rapide :

```text
Products
Sales
Customers
Orders
Tables
Invoices
Suppliers
```

---

# 61. MOBILE MONEY

Préparer l'architecture pour les paiements Mobile Money.

Le paiement doit pouvoir fonctionner selon le fournisseur et l'intégration disponible.

Ne jamais bloquer une vente si l'intégration distante est temporairement indisponible.

---

# 62. TESTS

Créer :

### Unit Tests

* taxes ;
* discounts ;
* totals ;
* unit conversion ;
* stock ;
* payment ;
* change.

### BLoC Tests

Tous les BLoCs.

### Integration Tests

```text
Login
→ Product
→ Cart
→ Payment
→ Receipt
→ Sync
```

### Offline Tests

```text
Internet OFF
→ Sale
→ Save
→ Master
→ Internet ON
→ Cloud Sync
```

### Network Tests

Tester :

```text
Master discovery
Pairing
Reconnect
Heartbeat
Master unavailable
Slave offline
```

### Printer Tests

Tester :

```text
Discovery
Connection
Print
Failure
Retry
Fallback
```

---

# 63. VERSIONING

Toutes les données synchronisées doivent être versionnées.

Exemple :

```text
configuration_version
data_version
schema_version
app_version
protocol_version
```

Le Master doit vérifier la compatibilité des versions avant d'autoriser un Slave.

---

# 64. HEALTH CHECK

Le Master expose :

```text
/health
```

Réponse :

```json
{
  "status": "healthy",
  "database": true,
  "printer_service": true,
  "sync_service": true,
  "network": true,
  "version": "1.0.0"
}
```

---

# 65. BACKUP

Le Master doit prévoir :

* backup local ;
* export de données ;
* restauration ;
* backup automatique ;
* synchronisation cloud.

Un commerce ne doit pas perdre ses ventes en cas de panne de l'appareil Master.

---

# 66. MASTER FAILOVER — ARCHITECTURE FUTURE

Préparer l'architecture pour :

```text
MASTER A
    │
    │ replication
    ▼
MASTER B
```

Si Master A tombe :

```text
MASTER A
OFFLINE
   ↓
MASTER B
ACTIVE
```

Cette fonctionnalité peut être développée ultérieurement mais l'architecture actuelle doit pouvoir l'accueillir.

---

# 67. WINDOWS DEVICE INTEGRATION

Sur Windows prévoir :

* imprimantes USB ;
* imprimantes réseau ;
* scanner ;
* cash drawer ;
* clavier ;
* souris ;
* écrans larges ;
* éventuellement customer display.

---

# 68. ANDROID DEVICE INTEGRATION

Sur Android prévoir :

* caméra barcode scanner ;
* Bluetooth ;
* Wi-Fi ;
* réseau local ;
* imprimantes compatibles ;
* tablette ;
* écran tactile ;
* biométrie ;
* stockage local.

---

# 69. CONFIGURATION CENTRALISÉE

Le Master doit pouvoir pousser automatiquement :

```text
Products
Prices
Categories
Taxes
Printers
Printer Routes
Tables
Restaurant Settings
POS Settings
Payment Methods
Permissions
```

vers les Slaves.

---

# 70. PROVISIONING AUTOMATIQUE

Lorsqu'un Slave est associé :

```text
PAIR
 ↓
AUTHENTICATE
 ↓
DOWNLOAD CONFIGURATION
 ↓
DOWNLOAD PRODUCTS
 ↓
DOWNLOAD PRICES
 ↓
DOWNLOAD TABLES
 ↓
DOWNLOAD PRINTER CONFIG
 ↓
INITIAL SYNC
 ↓
READY
```

L'utilisateur ne doit pas configurer manuellement chaque élément.

---

# 71. CONFIGURATION DES IMPRIMANTES — CAS RESTAURANT

Exemple :

```text
Product Category

Drinks
 → BAR-PRINTER

Food
 → KITCHEN-PRINTER

Dessert
 → DESSERT-PRINTER
```

Commande :

```text
Table 12

2 × Beer
1 × Pizza
1 × Coffee
```

Résultat :

```text
BAR
→ Beer

KITCHEN
→ Pizza

BAR
→ Coffee

CASHIER
→ Receipt
```

---

# 72. PRINTER STATUS

Afficher :

```text
🟢 Online
🟡 Busy
🔴 Offline
⚠️ Paper Low
❌ Error
```

Si le matériel permet de remonter ces informations.

---

# 73. POS HEALTH STATUS

Chaque terminal doit afficher :

```text
POS STATUS

Database       🟢
Master         🟢
Internet       🟢
Cloud          🟢
Printer        🟢
Sync           🟢
```

---

# 74. BUSINESS CONTINUITY

Le système doit respecter cette règle :

> Une panne d'Internet ne doit jamais arrêter le commerce.

Et autant que possible :

> Une panne du Master ne doit pas empêcher les Slaves de continuer temporairement à vendre.

Et :

> Une panne d'une imprimante ne doit jamais annuler une vente.

---

# 75. PRIORITÉ ARCHITECTURALE

Ordre de priorité :

```text
1. OFFLINE-FIRST
2. LOCAL DATABASE
3. MASTER / SLAVE
4. NETWORK DISCOVERY
5. SYNCHRONIZATION
6. PRINTER MANAGEMENT
7. POS TRANSACTIONS
8. SECURITY
9. REALTIME
10. CLOUD ERP
```

---

# 76. PHASES DE DÉVELOPPEMENT

## PHASE 1 — FOUNDATION

Créer :

* Flutter project ;
* Clean Architecture ;
* BLoC ;
* SQLite ;
* DI ;
* routing ;
* theme ;
* logging ;
* configuration.

## PHASE 2 — NETWORK CORE

Créer :

* Master ;
* local API ;
* discovery ;
* pairing ;
* heartbeat ;
* device registry ;
* reconnection.

## PHASE 3 — OFFLINE ENGINE

Créer :

* local repositories ;
* outbox ;
* sync queue ;
* idempotency ;
* conflict resolution.

## PHASE 4 — PRINTER ENGINE

Créer :

* printer discovery ;
* printer manager ;
* printer groups ;
* routing ;
* print queue ;
* retry ;
* fallback.

## PHASE 5 — POS CORE

Créer :

* products ;
* categories ;
* scanner ;
* cart ;
* checkout ;
* payment ;
* sales ;
* receipt.

## PHASE 6 — CASH

Créer :

* cash register ;
* shifts ;
* cash movements ;
* reconciliation.

## PHASE 7 — RESTAURANT

Créer :

* tables ;
* orders ;
* kitchen ;
* modifiers ;
* extras ;
* split ;
* merge.

## PHASE 8 — INVENTORY

Créer :

* stock ;
* movements ;
* stock count ;
* cycle count ;
* transfers.

## PHASE 9 — CLOUD

Connecter :

```text
Master
 ↓
Laravel API
 ↓
ITARA ERP
```

## PHASE 10 — REALTIME

Intégrer :

```text
Laravel Reverb
WebSockets
```

## PHASE 11 — SECURITY

Finaliser :

* permissions ;
* audit ;
* secure storage ;
* PIN ;
* biométrie ;
* device authorization.

## PHASE 12 — PRODUCTION

Faire :

* unit tests ;
* BLoC tests ;
* integration tests ;
* offline tests ;
* network tests ;
* printer tests ;
* performance tests ;
* crash handling ;
* logging ;
* Android APK/AAB ;
* Windows production build.

---

# 77. RÈGLES DE CODE

Ne jamais :

* mettre toute l'application dans un seul fichier ;
* mettre la logique métier dans les widgets ;
* utiliser `setState` pour la logique globale ;
* dépendre constamment d'Internet ;
* hardcoder les IP ;
* hardcoder les URLs ;
* ignorer les erreurs de synchronisation ;
* créer de doublons ;
* faire dépendre une vente d'une impression réussie ;
* faire dépendre une vente d'Internet.

Toujours :

* utiliser BLoC ;
* utiliser Repository Pattern ;
* utiliser Use Cases ;
* utiliser SQLite ;
* utiliser transactions DB ;
* utiliser UUID ;
* utiliser idempotency keys ;
* journaliser les erreurs ;
* tester les opérations critiques.

---

# 78. OBJECTIF FINAL

Le produit final doit être un véritable :

# ITARA DISTRIBUTED POS PLATFORM

et non simplement une application de caisse.

Il doit fonctionner comme :

```text
POS TERMINAL
+
LOCAL EDGE SERVER
+
OFFLINE ENGINE
+
MASTER/SLAVE NETWORK
+
PRINTER SERVER
+
SYNC ENGINE
+
CLOUD ERP CLIENT
+
REALTIME SYSTEM
```

Architecture finale :

```text
                         ┌─────────────────────┐
                         │     ITARA ERP       │
                         │      CLOUD         │
                         │ Laravel + Vue       │
                         └──────────┬──────────┘
                                    │
                              REST / Reverb
                                    │
                              INTERNET
                                    │
                                    ▼
                     ┌─────────────────────────┐
                     │       MASTER POS        │
                     │                         │
                     │ Flutter                 │
                     │ SQLite                  │
                     │ Local API               │
                     │ Discovery               │
                     │ Sync Engine             │
                     │ Printer Manager          │
                     │ Device Manager           │
                     │ Realtime                 │
                     └────────────┬────────────┘
                                  │
                           LOCAL NETWORK
                                  │
               ┌──────────────────┼──────────────────┐
               │                  │                  │
               ▼                  ▼                  ▼
        ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
        │ Android POS │    │ Windows POS │    │   Kitchen   │
        │   SLAVE     │    │   SLAVE     │    │   DISPLAY   │
        └──────┬──────┘    └──────┬──────┘    └─────────────┘
               │                  │
               └────────┬─────────┘
                        │
                        ▼
                ┌───────────────┐
                │ LOCAL PRINTER │
                │    SYSTEM     │
                └───────┬───────┘
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
       RECEIPT        KITCHEN        BAR
       PRINTER        PRINTER       PRINTER
```

## RÉSULTAT ATTENDU

L'application doit être :

**Native Flutter + Flutter BLoC + Offline-First + Master/Slave + Auto-Discovery + Local Network + SQLite + Printer Management + Realtime + Cloud Sync + Multi-Tenant + Multi-Branch + Android + Windows + Restaurant + POS.**

Elle doit être conçue dès le départ pour pouvoir évoluer vers un véritable **Operating System de commerce ITARA**, où un établissement peut installer un Master, connecter automatiquement ses POS, ses imprimantes, ses écrans cuisine et fonctionner même lorsque l'Internet est totalement indisponible.
