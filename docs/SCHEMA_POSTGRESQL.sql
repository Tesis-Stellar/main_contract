-- Esquema PostgreSQL para Stellar Tickets Platform
-- Todo lo relacionado with tickets, usuarios, eventos, transacciones, auditoría

-- Primero, extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. SCHEMA BASE: Usuarios y Roles
-- ============================================================================

CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    direccion_stellar VARCHAR(56) UNIQUE NOT NULL, -- Stellar address format
    email VARCHAR(255),
    nombre_completo VARCHAR(256),
    rol VARCHAR(50) NOT NULL DEFAULT 'comprador', -- comprador, vendedor, organizador, admin, verificador
    estado VARCHAR(20) NOT NULL DEFAULT 'activo', -- activo, suspendido, eliminado
    datos_kyc JSONB, -- {documento_id, documento_tipo, pais, verificado_fecha}
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_usuarios_direccion ON usuarios(direccion_stellar);
CREATE INDEX idx_usuarios_rol ON usuarios(rol);

-- ============================================================================
-- 2. SCHEMA BASE: Eventos
-- ============================================================================

CREATE TABLE eventos (
    id SERIAL PRIMARY KEY,
    id_evento_blockchain INT NOT NULL UNIQUE, -- Referencia al id_evento en contrato
    nombre VARCHAR(256) NOT NULL,
    descripcion TEXT,
    ubicacion VARCHAR(512),
    fecha_evento TIMESTAMP NOT NULL,
    capacidad_total INT NOT NULL,
    cantidad_vendida INT DEFAULT 0,
    cantidad_revendida INT DEFAULT 0,
    cantidad_usada INT DEFAULT 0,
    estado VARCHAR(50) NOT NULL DEFAULT 'en_venta', -- en_venta, cancelado, finalizado
    organizador_id UUID REFERENCES usuarios(id),
    token_pago VARCHAR(56), -- Stellar asset code/contract (ej: native XLM or USDC_sim)
    comision_organizador DECIMAL(5, 2) DEFAULT 20, -- Porcentaje
    comision_plataforma DECIMAL(5, 2) DEFAULT 10,
    wallet_organizador VARCHAR(56),
    wallet_plataforma VARCHAR(56),
    metadata JSONB, -- {imagen, categoria, tags, etc}
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_eventos_id_blockchain ON eventos(id_evento_blockchain);
CREATE INDEX idx_eventos_organizador ON eventos(organizador_id);
CREATE INDEX idx_eventos_estado ON eventos(estado);

-- ============================================================================
-- 3. SCHEMA BOLETOS: Root + Versionado
-- ============================================================================

CREATE TABLE boletos_raiz (
    id_raiz SERIAL PRIMARY KEY,
    ticket_root_id INT NOT NULL UNIQUE, -- ID original en blockchain (nunca cambia)
    id_evento INT NOT NULL REFERENCES eventos(id),
    propietario_original UUID REFERENCES usuarios(id),
    precio_original NUMERIC(20, 7) NOT NULL, -- Es en stroops (XLM * 10^7)
    es_primario BOOL DEFAULT true,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    quemado BOOL DEFAULT false -- Fase C: si true, no puede revenderse más
);

CREATE INDEX idx_boletos_raiz_evento ON boletos_raiz(id_evento);
CREATE INDEX idx_boletos_raiz_propietario ON boletos_raiz(propietario_original);
CREATE UNIQUE INDEX idx_boletos_raiz_blockchain_id ON boletos_raiz(ticket_root_id);


CREATE TABLE boletos_version (
    id_version SERIAL PRIMARY KEY,
    id_raiz INT NOT NULL REFERENCES boletos_raiz(id_raiz),
    numero_version INT NOT NULL DEFAULT 0,
    propietario_id UUID REFERENCES usuarios(id) NOT NULL,
    precio NUMERIC(20, 7),
    en_venta BOOL DEFAULT false,
    es_reventa BOOL DEFAULT false,
    usado BOOL DEFAULT false,
    hash_transaccion_creacion VARCHAR(64), -- Stellar tx hash que creó esta versión
    hash_transaccion_quemado VARCHAR(64), -- Fase C: hash de tx de burn
    marcado_en TIMESTAMP, -- Cuando se marcó como usado
    verificador_id UUID REFERENCES usuarios(id), -- Quién (rol verificador) marcó como usado
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(id_raiz, numero_version)
);

CREATE INDEX idx_boletos_version_propietario ON boletos_version(propietario_id);
CREATE INDEX idx_boletos_version_num ON boletos_version(numero_version);
CREATE INDEX idx_boletos_version_en_venta ON boletos_version(en_venta);
CREATE INDEX idx_boletos_version_usado ON boletos_version(usado);

-- ============================================================================
-- 4. SCHEMA REVENTA
-- ============================================================================

CREATE TABLE listados_reventa (
    id SERIAL PRIMARY KEY,
    id_version INT NOT NULL REFERENCES boletos_version(id_version),
    propietario_vendedor UUID REFERENCES usuarios(id) NOT NULL,
    precio_reventa NUMERIC(20, 7) NOT NULL,
    fecha_listado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cancelado BOOL DEFAULT false,
    cancelado_en TIMESTAMP,
    razon_cancelacion VARCHAR(512)
);

CREATE INDEX idx_listados_reventa_vendedor ON listados_reventa(propietario_vendedor);
CREATE INDEX idx_listados_reventa_activos ON listados_reventa(cancelado) WHERE cancelado = false;


CREATE TABLE transacciones_reventa (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_version_origen INT NOT NULL REFERENCES boletos_version(id_version),
    vendedor_id UUID REFERENCES usuarios(id) NOT NULL,
    comprador_id UUID REFERENCES usuarios(id) NOT NULL,
    precio_reventa NUMERIC(20, 7) NOT NULL,
    comision_organizador NUMERIC(20, 7) NOT NULL,
    comision_plataforma NUMERIC(20, 7) NOT NULL,
    comision_vendedor NUMERIC(20, 7) NOT NULL,
    wallet_organizador VARCHAR(56),
    wallet_plataforma VARCHAR(56),
    wallet_vendedor VARCHAR(56),
    hash_transaccion_stellar VARCHAR(64) NOT NULL UNIQUE, -- Idempotencia clave
    estado VARCHAR(50) DEFAULT 'completada', -- completada, fallida, revertida
    detalles_error TEXT,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transacciones_reventa_vendedor ON transacciones_reventa(vendedor_id);
CREATE INDEX idx_transacciones_reventa_comprador ON transacciones_reventa(comprador_id);
CREATE INDEX idx_transacciones_reventa_hash ON transacciones_reventa(hash_transaccion_stellar);
CREATE INDEX idx_transacciones_reventa_estado ON transacciones_reventa(estado);

-- ============================================================================
-- 5. SCHEMA VERIFICACIÓN: Check-ins y Offline
-- ============================================================================

CREATE TABLE checkins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_version INT NOT NULL REFERENCES boletos_version(id_version),
    evento_id INT NOT NULL REFERENCES eventos(id),
    usuario_ingreso_id UUID REFERENCES usuarios(id),
    verificador_id UUID REFERENCES usuarios(id), -- Quién verificó
    timestamp_verificacion TIMESTAMP NOT NULL,
    estado_verificacion VARCHAR(50) NOT NULL DEFAULT 'verificado', -- verificado, rechazado, duplicado
    metadata_qr JSONB, -- {qr_content, qr_version, qr_timestamp_lectura}
    ubicacion_gps JSONB, -- {latitud, longitud} (opcional para auditoría)
    es_offline BOOL DEFAULT false,
    hash_transaccion_sincronizacion VARCHAR(64), -- Cuando se sincronizó on-chain
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_checkins_evento ON checkins(evento_id);
CREATE INDEX idx_checkins_verificador ON checkins(verificador_id);
CREATE INDEX idx_checkins_timestamp ON checkins(timestamp_verificacion);
CREATE INDEX idx_checkins_offline ON checkins(es_offline);


CREATE TABLE cache_verificacion_offline (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_version INT NOT NULL REFERENCES boletos_version(id_version),
    qr_hash VARCHAR(64) NOT NULL UNIQUE,
    datos_ticket JSONB, -- {id_boleto, id_evento, propietario, usado}
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expira_en TIMESTAMP NOT NULL, -- 30 minutos típicamente
    sincronizado BOOL DEFAULT false
);

CREATE INDEX idx_cache_offline_qr ON cache_verificacion_offline(qr_hash);
CREATE INDEX idx_cache_offline_vencido ON cache_verificacion_offline(expira_en);

-- ============================================================================
-- 6. SCHEMA INDEXADOR: Control de sincronización
-- ============================================================================

CREATE TABLE indexador_cursor (
    id SERIAL PRIMARY KEY,
    ultimo_ledger_procesado INT NOT NULL DEFAULT 0,
    ultima_tx_procesada VARCHAR(64),
    fecha_ultima_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(50) DEFAULT 'activo', -- activo, pausado, error
    eventos_procesados INT DEFAULT 0
);

CREATE TABLE eventos_procesados (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hash_transaccion_stellar VARCHAR(64) NOT NULL,
    tipo_evento VARCHAR(50) NOT NULL, -- TicketMinted, TicketResold, etc
    datos_evento JSONB NOT NULL,
    procesado BOOL DEFAULT true,
    ledger_numero INT,
    fecha_evento TIMESTAMP,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(hash_transaccion_stellar, tipo_evento)
);

CREATE INDEX idx_eventos_procesados_tipo ON eventos_procesados(tipo_evento);
CREATE INDEX idx_eventos_procesados_hash ON eventos_procesados(hash_transaccion_stellar);
CREATE INDEX idx_eventos_procesados_ledger ON eventos_procesados(ledger_numero);

-- ============================================================================
-- 7. SCHEMA AUDITORÍA
-- ============================================================================

CREATE TABLE auditoria (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID REFERENCES usuarios(id),
    tipo_operacion VARCHAR(100) NOT NULL, -- crear_boleto, comprar_boleto, redimir, listar_reventa, etc
    entidad_tipo VARCHAR(50) NOT NULL, -- boleto, evento, usuario, transaccion
    entidad_id VARCHAR(256),
    cambios_json JSONB, -- antes y después
    ip_origen INET,
    user_agent TEXT,
    estado_operacion VARCHAR(50) DEFAULT 'exitosa', -- exitosa, fallida
    razon_fallo TEXT,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id);
CREATE INDEX idx_auditoria_tipo ON auditoria(tipo_operacion);
CREATE INDEX idx_auditoria_entidad ON auditoria(entidad_tipo, entidad_id);
CREATE INDEX idx_auditoria_fecha ON auditoria(creado_en);

-- ============================================================================
-- 8. FUNCIONES Y TRIGGERS
-- ============================================================================

-- Trigger para actualizar timestamp
CREATE OR REPLACE FUNCTION actualizar_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_usuarios_timestamp
BEFORE UPDATE ON usuarios
FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

CREATE TRIGGER trigger_eventos_timestamp
BEFORE UPDATE ON eventos
FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

CREATE TRIGGER trigger_boletos_version_timestamp
BEFORE UPDATE ON boletos_version
FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

-- ============================================================================
-- 9. VISTAS ÚTILES
-- ============================================================================

CREATE VIEW vista_boletos_actuales AS
SELECT 
    r.ticket_root_id,
    r.id_raiz,
    v.id_version,
    v.numero_version,
    v.propietario_id,
    v.precio,
    v.en_venta,
    v.es_reventa,
    v.usado,
    e.id as evento_id,
    e.nombre as evento_nombre,
    u.direccion_stellar as propietario_direccion
FROM boletos_raiz r
JOIN boletos_version v ON r.id_raiz = v.id_raiz
JOIN eventos e ON r.id_evento = e.id
JOIN usuarios u ON v.propietario_id = u.id
WHERE v.numero_version = (
    SELECT MAX(numero_version) FROM boletos_version bv WHERE bv.id_raiz = r.id_raiz
);

CREATE VIEW vista_reventa_disponible AS
SELECT 
    lr.id,
    lr.precio_reventa,
    v.propietario_id,
    v.usado,
    e.nombre as evento_nombre,
    u.direccion_stellar as vendedor_direccion
FROM listados_reventa lr
JOIN boletos_version v ON lr.id_version = v.id_version
JOIN boletos_raiz r ON v.id_raiz = r.id_raiz
JOIN eventos e ON r.id_evento = e.id
JOIN usuarios u ON v.propietario_id = u.id
WHERE lr.cancelado = false AND v.usado = false;

-- ============================================================================
-- 10. COMENTARIOS DOCUMENTACIÓN
-- ============================================================================

COMMENT ON TABLE boletos_raiz IS 'Identidad inmutable de un boleto. ticket_root_id nunca cambia aunque se revenda.';
COMMENT ON TABLE boletos_version IS 'Estado actual de un boleto. Cada reventa genera nueva versión. Linked a blockchain via hash_transaccion.';
COMMENT ON COLUMN boletos_version.numero_version IS 'v0=primario, v1=primera reventa, v2=segunda reventa, etc. Cada burn+remint incrementa este.';
COMMENT ON TABLE transacciones_reventa IS 'Auditoría de reventas. hash_transaccion_stellar es clave de idempotencia vs indexador.';
COMMENT ON TABLE cache_verificacion_offline IS 'Caché de QRs válidos durante ventana offline (~30 min). Expira y se sincroniza después.';
COMMENT ON TABLE eventos_procesados IS 'Ledger de eventos consumidos del blockchain. UNIQUE constraint previene reindexing duplicados.';
