# Blasa — partie NoSQL (Redis)

> Covoiturage étudiant en Tunisie. Ce dépôt présente la **base de données Redis** du projet Blasa
> (module **Bases de données NoSQL**, Pr. Senda Bouaziz).
> L'API REST et l'interface web sont dans le dépôt [**Blasa-services-web**](https://github.com/nessryne-chouchene/Blasa-services-web) (module Services Web).

**Auteurs :** Nessryne Chouchene, Omayma Hamdy — Data Engineering, Faculté des Sciences de Sfax (FSS)

## L'idée

Un conducteur propose des places, un passager cherche un trajet près de lui ou entre deux villes,
réserve une place puis note son conducteur. Redis (clé-valeur, en mémoire) répond à chaque besoin
avec une structure native, sans jointure.

## Pourquoi Redis ?

| Besoin | Structure Redis | Commande clé |
|---|---|---|
| Lire un trajet ou un profil | `HASH` | `HGETALL` |
| Trajets autour d'un point | `GEO` | `GEOSEARCH` |
| Trajets Sfax → Tunis | `SET` par ville | `SINTER` |
| Réserver sans surréservation | compteur atomique | `HINCRBY` |
| Éviter les doublons de passagers | `SET` | `SISMEMBER`, `SADD` |
| Meilleurs conducteurs | `ZSET` | `ZREVRANGE` |
| Un trajet passé disparaît | expiration | `EXPIREAT` |
| Prévenir les autres écrans en direct | Pub/Sub | `PUBLISH`, `SUBSCRIBE` |

## Modèle de données

| Clé | Type | Contenu |
|---|---|---|
| `seq:user`, `seq:ride` | chaîne | dernier identifiant attribué (`INCR`) |
| `user:{id}` | HASH | `name`, `email`, `city`, `ratingSum`, `ratingCount` |
| `ride:{id}` | HASH | `driverId`, `origin`, `destination`, `departureAt`, `seats`, `seatsLeft`, `price`, `status` (TTL au départ) |
| `ride:{id}:passengers` | SET | identifiants des passagers (TTL au départ) |
| `rides:geo` | GEO | position de départ de chaque trajet |
| `rides:from:{ville}`, `rides:to:{ville}` | SET | index par ville |
| `leaderboard:drivers` | ZSET | note moyenne de chaque conducteur |
| `stats:summary` | HASH | `ridesCreated`, `bookings`, `ratings` |
| canal `blasa:events` | Pub/Sub | événements en direct (JSON) |

## Lancer la démo

Prérequis : **Docker Desktop** ouvert.

1. Double-cliquer sur `load-demo.cmd` (ou `powershell -ExecutionPolicy Bypass -File .\load-demo.ps1`).
   Redis démarre et 8 trajets sont chargés, avec des départs dans 20 à 50 heures.
2. Ouvrir `redis-cli` :

```powershell
docker exec -it blasa-redis redis-cli
```

3. Essayer les requêtes (aussi dans `redis/02_queries.redis`) :

```
HGETALL ride:1
GEOSEARCH rides:geo FROMLONLAT 10.76 34.74 BYRADIUS 50 km ASC WITHDIST
SINTER rides:from:sfax rides:to:tunis
ZREVRANGE leaderboard:drivers 0 2 WITHSCORES
HINCRBY ride:1 seatsLeft -1
TTL ride:1
```

### Démo du TTL

```
HSET ride:99 origin sfax destination tunis seats 2 seatsLeft 2 price 10 status OPEN
EXPIRE ride:99 30
TTL ride:99
```

Attendre 30 secondes, puis `EXISTS ride:99` renvoie `0` : Redis a supprimé la clé tout seul.

### Démo du Pub/Sub (deux terminaux)

Terminal 1 — s'abonner au canal :

```powershell
docker exec -it blasa-redis redis-cli SUBSCRIBE blasa:events
```

Terminal 2 — publier un événement :

```powershell
docker exec -it blasa-redis redis-cli
PUBLISH blasa:events '{"type":"booked","rideId":2,"userId":3,"seatsLeft":3}'
```

Le message apparaît immédiatement dans le terminal 1.

## Contenu du dépôt

| Dossier / fichier | Rôle |
|---|---|
| `docker-compose.yml` | lance Redis 7 |
| `redis/01_seed.template.redis` | modèle des données de démo |
| `redis/02_queries.redis` | les 7 requêtes de démonstration |
| `load-demo.ps1` / `load-demo.cmd` | génère les dates et charge les données |
| `rapports/rapport_nosql.tex` | rapport (LaTeX, à compiler avec pdfLaTeX, par exemple sur Overleaf) |

## Limites connues

- Données en mémoire, sans volume Docker : elles disparaissent avec le conteneur.
- Plusieurs commandes de la réservation ne forment pas une transaction (`MULTI/EXEC` ou script Lua à prévoir).
- L'expiration supprime la fiche du trajet mais pas ses entrées dans les index : elles sont nettoyées à la lecture suivante.
- Le Pub/Sub ne conserve pas les messages (Redis Streams serait l'alternative).
