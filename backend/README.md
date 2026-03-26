# TuTicket Backend

Backend mock de una plataforma tradicional de ticketing primario para Colombia. Simula el flujo normal de compra de entradas de un sitio tipo Ticketmaster o TuBoleta: exploracion de eventos, detalle, disponibilidad, seleccion de asientos cuando aplica, carrito, checkout, ordenes, tickets y panel admin basico.

## Stack

- Node.js
- TypeScript
- NestJS
- PostgreSQL
- Prisma ORM
- JWT Authentication
- Swagger / OpenAPI
- class-validator
- Docker

## Alcance

Este proyecto implementa solo venta primaria.

- Incluye: eventos, venues, seat maps, ticket types, carrito, seat holds temporales, checkout, ordenes, tickets e historial.
- No incluye: resale marketplace, reventa, blockchain, NFTs, trazabilidad de autenticidad, mercado secundario, integraciones B2B ni lenguaje crypto.

## Estructura

```text
src/
  common/
  modules/
    admin/
    auth/
    cart/
    checkout/
    events/
    orders/
    seatmaps/
    tickets/
    users/
    venues/
  prisma/
prisma/
test/
```

## Variables De Entorno

Copiar `.env.example` a `.env` y ajustar valores:

```env
PORT=3000
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/tuticket?schema=public"
JWT_SECRET="super-secret-jwt-key"
JWT_EXPIRES_IN="7d"
SEAT_HOLD_MINUTES=10
SWAGGER_PATH=api/docs
```

## Instalacion Local

```bash
npm install
```

## Base De Datos Y Migraciones

1. Levanta PostgreSQL local o con Docker.
2. Ejecuta migraciones.
3. Genera el cliente Prisma.
4. Carga seed.

```bash
npm run prisma:generate
npx prisma migrate dev
npm run seed
```

Si prefieres aplicar migraciones existentes en un entorno no interactivo:

```bash
npm run prisma:deploy
```

## Ejecutar En Desarrollo

```bash
npm run start:dev
```

La API queda disponible en:

- API base: [http://localhost:3000/api](http://localhost:3000/api)
- Swagger: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)

## Credenciales De Ejemplo

- Admin
  - Email: `admin@tuticket.mock`
  - Password: `TuTicket123*`
- Customer
  - Email: `juan@tuticket.mock`
  - Password: `TuTicket123*`
- Customer con historial adicional
  - Email: `maria@tuticket.mock`
  - Password: `TuTicket123*`

## Seed Incluido

El seed crea datos realistas para Colombia:

- Ciudades: Bogotá, Medellín, Cali, Barranquilla, Cartagena y Bucaramanga.
- Eventos de conciertos, teatro, deportes, festivales, comedia y familiar.
- Venues multiples.
- Un evento con seat map numerado y secciones `VIP`, `Platea`, `Preferencial`, `General`, `Occidental` y `Oriental`.
- Usuarios, ordenes y tickets para poblar homepage, listing, detalle, checkout e historial.

Ejecutar seed:

```bash
npm run seed
```

## Endpoints Principales

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/events`
- `GET /api/events/featured`
- `GET /api/events/categories`
- `GET /api/events/:slug`
- `GET /api/events/:id/ticket-types`
- `GET /api/events/:id/availability`
- `GET /api/events/:id/seatmap`
- `GET /api/events/:id/seats/availability`
- `GET /api/cart`
- `POST /api/cart/items`
- `POST /api/checkout/preview`
- `POST /api/checkout/confirm`
- `GET /api/orders`
- `GET /api/tickets`
- `GET /api/admin/dashboard`

## Notas Importantes

- Los seat holds duran `10` minutos por defecto y se validan o liberan en operaciones sensibles del carrito, seatmap y checkout.
- Para eventos numerados, los asientos se bloquean temporalmente al agregarlos al carrito y no pueden comprarse dos veces.
- El checkout simula pago exitoso si todas las validaciones pasan.
- Los metodos de pago mock soportados son `CARD`, `PSE` y `CASHPOINT`.
- El campo QR del ticket es un placeholder string y no integra un proveedor real de codigos QR.

## Pruebas

Ejecutar pruebas unitarias:

```bash
npm test
```

## Docker

Levantar API + PostgreSQL:

```bash
docker compose up --build
```

Luego aplica seed manualmente dentro del contenedor de la API o desde tu entorno local apuntando al contenedor:

```bash
npm run seed
```
