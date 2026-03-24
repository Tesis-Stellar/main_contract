# Stellar Tickets On-Chain (Soroban)

Submódulo on-chain del monorepo **Stellar Tickets**, orientado a una arquitectura con `factory_contract` y `event_contract`.

## Estructura actual

```text
.
├── contracts/
│   ├── event_contract/
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   └── test.rs
│   │   └── Cargo.toml
│   └── factory_contract/
│       ├── src/
│       │   └── lib.rs
│       └── Cargo.toml
├── Cargo.toml
├── Cargo.lock
├── ESPECIFICACION_SIMULACION_ADMIN_OFFCHAIN.md
└── ROADMAP_TECNICO_CONTRATOS.md
```

## Estado actual

- `event_contract` es el contrato funcional vigente.
- `event_contract` ya incorpora la logica de venta primaria, reventa y redencion migrada desde el contrato legado.
- `factory_contract` ya implementa inicializacion, control administrativo, registro por `id_evento`, validaciones y evento on-chain.
- Falta el paso de despliegue real del contrato hijo desde factory en testnet/futurenet.

## Funcionalidad implementada en `event_contract`

- Inicialización del contrato con `organizador`, `plataforma`, `token_pago` y porcentajes de comisión.
- Creación de boletos por organizador.
- Listado, cancelación de venta y compra de boletos.
- Diferenciación entre venta primaria y reventa.
- Distribución de comisiones en reventa.
- Redención de boleto para control de acceso.
- Consultas por boleto, propietario, boletos en reventa y boletos por evento.

## Reglas de validación actuales

- No permite inicialización doble.
- Comisiones inválidas si son negativas o si su suma es `>= 100`.
- Precio de ticket/listado debe ser mayor que `0`.
- No permite compra de ticket no listado, usado o auto-compra.

## Comandos de trabajo

Desde la raiz del workspace Rust:

```bash
cargo test -p event_contract
cargo fmt --all
```

Para compilar el WASM de un contrato específico:

```bash
stellar contract build --package event_contract
stellar contract build --package factory_contract
```

## Estado del roadmap

El plan técnico completo de evolución está en:

- `ROADMAP_TECNICO_CONTRATOS.md`

La ruta inmediata de implementación es:

1. Completar deploy real desde `factory_contract`.
2. Consolidar eventos on-chain estructurados para indexación.
3. Desplegar en testnet y fijar direcciones de contrato.
4. Consolidar integración con `../off_chain`.

## Concordancia con componentes off-chain

Para el alcance de tesis, este directorio **no absorbe toda la lógica de aplicación**. La arquitectura consolidada del monorepo es:

1. **`tesis_main_contract/`**: contratos Soroban (`factory` y `event`).
2. **`../off_chain/`**: backend API, indexador, base de datos, frontend white-label y módulo de verificación.

### Qué debe quedarse on-chain

- Propiedad del boleto.
- Reglas de compra/reventa.
- Comisiones.
- Redención/consumo del boleto.
- Eventos mínimos para indexación.

### Qué debe quedarse off-chain

- Usuarios, perfiles y autenticación.
- Historial enriquecido de trazabilidad.
- Marketplace consultable y filtros.
- Generación y validación de QR.
- Modo offline y reconciliación.
- Auditoría operativa y analítica.
- Modelo administrativo de eventos, zonas y sillas.

### Documento guía para el equipo off-chain

La especificación operativa para la simulación de la página web administrativa está en:

- `ESPECIFICACION_SIMULACION_ADMIN_OFFCHAIN.md`

Para la vista general del monorepo, ver `../README.md`.
