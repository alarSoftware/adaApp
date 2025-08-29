const express = require('express');
const cors = require('cors');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

//login
app.use((req, res, next) => {
    const time = new Date().toLocaleString('es-PY', { timeZone: 'America/Asuncion' });
    console.log(`\n[${time}] ${req.method} ${req.url}`);
    if (req.body && Object.keys(req.body).length > 0) {
        console.log('Body:', JSON.stringify(req.body, null, 2));
    }
    next();
});

// DATOS DE EJEMPLO 
let clientes = [
    { id: 1, nombre: 'Juan Pérez', email: 'juan@email.com', telefono: '0981-123456', direccion: 'Asunción', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 2, nombre: 'María García', email: 'maria@email.com', telefono: '0984-654321', direccion: 'Luque', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 3, nombre: 'Carlos López', email: 'carlos@email.com', telefono: '0985-789123', direccion: 'San Lorenzo', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 4, nombre: 'Ana Torres', email: 'ana@email.com', telefono: '0971-222333', direccion: 'Fernando de la Mora', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 5, nombre: 'Luis González', email: 'luis@email.com', telefono: '0972-444555', direccion: 'Lambaré', activo: false, fecha_creacion: new Date().toISOString() },
    { id: 6, nombre: 'Marta Rivas', email: 'marta@email.com', telefono: '0961-666777', direccion: 'Encarnación', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 7, nombre: 'Diego Silva', email: 'diego@email.com', telefono: '0962-888999', direccion: 'Capiatá', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 8, nombre: 'Lucía Benítez', email: 'lucia@email.com', telefono: '0983-121314', direccion: 'Itauguá', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 9, nombre: 'Pedro Duarte', email: 'pedro@email.com', telefono: '0986-151617', direccion: 'Villa Elisa', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 10, nombre: 'Gabriela Fernández', email: 'gaby@email.com', telefono: '0973-181920', direccion: 'Ñemby', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 11, nombre: 'Rodrigo Medina', email: 'rodrigo@email.com', telefono: '0963-212223', direccion: 'Caacupé', activo: false, fecha_creacion: new Date().toISOString() },
    { id: 12, nombre: 'Camila Ortiz', email: 'camila@email.com', telefono: '0974-242526', direccion: 'Coronel Oviedo', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 13, nombre: 'Santiago Cabrera', email: 'santiago@email.com', telefono: '0964-272829', direccion: 'Paraguarí', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 14, nombre: 'Patricia Villalba', email: 'patricia@email.com', telefono: '0987-303132', direccion: 'Ciudad del Este', activo: true, fecha_creacion: new Date().toISOString() },
    { id: 15, nombre: 'Hugo Ramírez', email: 'hugo@email.com', telefono: '0975-333444', direccion: 'Areguá', activo: true, fecha_creacion: new Date().toISOString() }
];


let logo = [
  { id: 1, nombre: 'Pulp' },
  { id: 2, nombre: 'Pepsi' },
  { id: 3, nombre: 'Paso de los Toros' },
  { id: 4, nombre: 'Mirinda' },
  { id: 5, nombre: '7Up' },
  { id: 6, nombre: 'Split' },
  { id: 7, nombre: 'Watts' },
  { id: 8, nombre: 'Puro Sol' },
  { id: 9, nombre: 'La Fuente' },
  { id: 10, nombre: 'Aquafina' },
  { id: 11, nombre: 'Gatorade' },
  { id: 12, nombre: 'Red Bull' },
  { id: 13, nombre: 'Rockstar' }
];

let equipos = [
  { id: 1, cod_barras: 'REF001', marca_id: 7, modelo_id: 23, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234567', logo_id: 9, estado_local: true },
  { id: 2, cod_barras: 'REF002', marca_id: 12, modelo_id: 5, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234568', logo_id: 3, estado_local: true },
  { id: 3, cod_barras: 'REF003', marca_id: 3, modelo_id: 41, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234569', logo_id: 11, estado_local: true },
  { id: 4, cod_barras: 'REF004', marca_id: 15, modelo_id: 16, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234570', logo_id: 7, estado_local: true },
  { id: 5, cod_barras: 'REF005', marca_id: 1, modelo_id: 34, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234571', logo_id: 13, estado_local: true },
  { id: 6, cod_barras: 'REF006', marca_id: 9, modelo_id: 2, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234572', logo_id: 1, estado_local: true },
  { id: 7, cod_barras: 'REF007', marca_id: 4, modelo_id: 47, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234573', logo_id: 8, estado_local: true },
  { id: 8, cod_barras: 'REF008', marca_id: 11, modelo_id: 12, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234574', logo_id: 5, estado_local: true },
  { id: 9, cod_barras: 'REF009', marca_id: 8, modelo_id: 39, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234575', logo_id: 12, estado_local: true },
  { id: 10, cod_barras: 'REF010', marca_id: 6, modelo_id: 18, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234576', logo_id: 4, estado_local: true },
  { id: 11, cod_barras: 'REF011', marca_id: 13, modelo_id: 29, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234577', logo_id: 10, estado_local: true },
  { id: 12, cod_barras: 'REF012', marca_id: 2, modelo_id: 6, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234578', logo_id: 6, estado_local: true },
  { id: 13, cod_barras: 'REF013', marca_id: 10, modelo_id: 43, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234579', logo_id: 2, estado_local: true },
  { id: 14, cod_barras: 'REF014', marca_id: 5, modelo_id: 15, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234580', logo_id: 9, estado_local: true },
  { id: 15, cod_barras: 'REF015', marca_id: 14, modelo_id: 31, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234581', logo_id: 7, estado_local: true },
  { id: 16, cod_barras: 'REF016', marca_id: 1, modelo_id: 9, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234582', logo_id: 13, estado_local: true },
  { id: 17, cod_barras: 'REF017', marca_id: 7, modelo_id: 45, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234583', logo_id: 3, estado_local: true },
  { id: 18, cod_barras: 'REF018', marca_id: 12, modelo_id: 21, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234584', logo_id: 11, estado_local: true },
  { id: 19, cod_barras: 'REF019', marca_id: 3, modelo_id: 37, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234585', logo_id: 1, estado_local: true },
  { id: 20, cod_barras: 'REF020', marca_id: 15, modelo_id: 4, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234586', logo_id: 8, estado_local: true },
  { id: 21, cod_barras: 'REF021', marca_id: 9, modelo_id: 26, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234587', logo_id: 5, estado_local: true },
  { id: 22, cod_barras: 'REF022', marca_id: 6, modelo_id: 13, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234588', logo_id: 12, estado_local: true },
  { id: 23, cod_barras: 'REF023', marca_id: 11, modelo_id: 42, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234589', logo_id: 4, estado_local: true },
  { id: 24, cod_barras: 'REF024', marca_id: 4, modelo_id: 7, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234590', logo_id: 10, estado_local: true },
  { id: 25, cod_barras: 'REF025', marca_id: 8, modelo_id: 38, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234591', logo_id: 6, estado_local: true },
  { id: 26, cod_barras: 'REF026', marca_id: 13, modelo_id: 19, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234592', logo_id: 2, estado_local: true },
  { id: 27, cod_barras: 'REF027', marca_id: 2, modelo_id: 35, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234593', logo_id: 9, estado_local: true },
  { id: 28, cod_barras: 'REF028', marca_id: 10, modelo_id: 11, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234594', logo_id: 7, estado_local: true },
  { id: 29, cod_barras: 'REF029', marca_id: 5, modelo_id: 48, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234595', logo_id: 13, estado_local: true },
  { id: 30, cod_barras: 'REF030', marca_id: 14, modelo_id: 22, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234596', logo_id: 3, estado_local: true },
  { id: 31, cod_barras: 'REF031', marca_id: 1, modelo_id: 33, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234597', logo_id: 11, estado_local: true },
  { id: 32, cod_barras: 'REF032', marca_id: 7, modelo_id: 8, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234598', logo_id: 1, estado_local: true },
  { id: 33, cod_barras: 'REF033', marca_id: 12, modelo_id: 40, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234599', logo_id: 8, estado_local: true },
  { id: 34, cod_barras: 'REF034', marca_id: 3, modelo_id: 17, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234600', logo_id: 5, estado_local: true },
  { id: 35, cod_barras: 'REF035', marca_id: 15, modelo_id: 44, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234601', logo_id: 12, estado_local: true },
  { id: 36, cod_barras: 'REF036', marca_id: 9, modelo_id: 1, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234602', logo_id: 4, estado_local: true },
  { id: 37, cod_barras: 'REF037', marca_id: 6, modelo_id: 30, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234603', logo_id: 10, estado_local: true },
  { id: 38, cod_barras: 'REF038', marca_id: 11, modelo_id: 14, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234604', logo_id: 6, estado_local: true },
  { id: 39, cod_barras: 'REF039', marca_id: 4, modelo_id: 46, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234605', logo_id: 2, estado_local: true },
  { id: 40, cod_barras: 'REF040', marca_id: 8, modelo_id: 25, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234606', logo_id: 9, estado_local: true },
  { id: 41, cod_barras: 'REF041', marca_id: 13, modelo_id: 36, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234607', logo_id: 7, estado_local: true },
  { id: 42, cod_barras: 'REF042', marca_id: 2, modelo_id: 10, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234608', logo_id: 13, estado_local: true },
  { id: 43, cod_barras: 'REF043', marca_id: 10, modelo_id: 49, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234609', logo_id: 3, estado_local: true },
  { id: 44, cod_barras: 'REF044', marca_id: 5, modelo_id: 24, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234610', logo_id: 11, estado_local: true },
  { id: 45, cod_barras: 'REF045', marca_id: 14, modelo_id: 32, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234611', logo_id: 1, estado_local: true },
  { id: 46, cod_barras: 'REF046', marca_id: 1, modelo_id: 20, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234612', logo_id: 8, estado_local: true },
  { id: 47, cod_barras: 'REF047', marca_id: 7, modelo_id: 50, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234613', logo_id: 5, estado_local: true },
  { id: 48, cod_barras: 'REF048', marca_id: 12, modelo_id: 3, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234614', logo_id: 12, estado_local: true },
  { id: 49, cod_barras: 'REF049', marca_id: 3, modelo_id: 27, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234615', logo_id: 4, estado_local: true },
  { id: 50, cod_barras: 'REF050', marca_id: 15, modelo_id: 28, fecha_creacion: new Date().toISOString(), numero_serie: 'SN001234616', logo_id: 10, estado_local: true },
];

let modelo = [
  { id: 1, modelo: 'RT38K5932SL'},
  { id: 2, modelo: 'GS65SPP1'},
  { id: 3, modelo: 'WRM35AKTWW'},
  { id: 4, modelo: 'DF35'},
  { id: 5, modelo: 'NR-BL389'},
  { id: 6, modelo: 'HS-384'},
  { id: 7, modelo: 'KSV36VI3P'},
  { id: 8, modelo: 'FRS-U20'},
  { id: 9, modelo: 'GTS18'},
  { id: 10, modelo: 'SJ-FS85'},
  { id: 11, modelo: 'RB29HSR2DWW'},
  { id: 12, modelo: 'GC-X247'},
  { id: 13, modelo: 'WRF535SMHZ'},
  { id: 14, modelo: 'TF39'},
  { id: 15, modelo: 'NR-BY602'},
  { id: 16, modelo: 'FGTR1837TF'},
  { id: 17, modelo: 'RT42'},
  { id: 18, modelo: 'PHRF380'},
  { id: 19, modelo: 'RCNE560E40ZXBR'},
  { id: 20, modelo: 'RK-60'},
  { id: 21, modelo: 'RT46K6230SL'},
  { id: 22, modelo: 'GC-B247'},
  { id: 23, modelo: 'WRF535SWHZ'},
  { id: 24, modelo: 'TF39X'},
  { id: 25, modelo: 'NR-BY702'},
  { id: 26, modelo: 'HS-484'},
  { id: 27, modelo: 'KSV39VI3P'},
  { id: 28, modelo: 'FRS-U30'},
  { id: 29, modelo: 'GTS20'},
  { id: 30, modelo: 'SJ-FS95'},
  { id: 31, modelo: 'RB32HSR2DWW'},
  { id: 32, modelo: 'GC-X307'},
  { id: 33, modelo: 'WRF555SMHZ'},
  { id: 34, modelo: 'TF49'},
  { id: 35, modelo: 'NR-BY802'},
  { id: 36, modelo: 'FGTR1847TF'},
  { id: 37, modelo: 'RT52'},
  { id: 38, modelo: 'PHRF480'},
  { id: 39, modelo: 'RCNE560E50ZXBR'},
  { id: 40, modelo: 'RK-80'},
  { id: 41, modelo: 'RT48K6230SL'},
  { id: 42, modelo: 'GC-B307'},
  { id: 43, modelo: 'WRF555SWHZ'},
  { id: 44, modelo: 'TF49X'},
  { id: 45, modelo: 'NR-BY902'},
  { id: 46, modelo: 'HS-584'},
  { id: 47, modelo: 'KSV40VI3P'},
  { id: 48, modelo: 'FRS-U40'},
  { id: 49, modelo: 'GTS22'},
  { id: 50, modelo: 'SJ-FS105'},
];

let marcas = [
  { id: 1, nombre: 'Samsung' },
  { id: 2, nombre: 'LG' },
  { id: 3, nombre: 'Whirlpool' },
  { id: 4, nombre: 'Electrolux' },
  { id: 5, nombre: 'Panasonic' },
  { id: 6, nombre: 'Midea' },
  { id: 7, nombre: 'Bosch' },
  { id: 8, nombre: 'Daewoo' },
  { id: 9, nombre: 'GE' },
  { id: 10, nombre: 'Sharp' },
  { id: 11, nombre: 'Frigidaire' },
  { id: 12, nombre: 'Hisense' },
  { id: 13, nombre: 'Philco' },
  { id: 14, nombre: 'Beko' },
  { id: 15, nombre: 'Koblenz' }
];

let usuarios = [
    { id: 1, nombre: 'Admin', email: 'admin@sistema.com', contraseña: 'admin123', rol: 'administrador', fecha_creacion: new Date().toISOString() },
    { id: 2, nombre: 'Técnico 1', email: 'tecnico1@sistema.com', contraseña: 'tec123', rol: 'tecnico', fecha_creacion: new Date().toISOString() },
    { id: 3, nombre: 'Técnico 2', email: 'tecnico2@sistema.com', contraseña: 'tec234', rol: 'tecnico', fecha_creacion: new Date().toISOString() },
    { id: 4, nombre: 'Técnico 3', email: 'tecnico3@sistema.com', contraseña: 'tec345', rol: 'tecnico', fecha_creacion: new Date().toISOString() },
    { id: 5, nombre: 'Supervisor', email: 'supervisor@sistema.com', contraseña: 'sup123', rol: 'supervisor', fecha_creacion: new Date().toISOString() },
    { id: 6, nombre: 'Gerente', email: 'gerente@sistema.com', contraseña: 'ger123', rol: 'administrador', fecha_creacion: new Date().toISOString() },
    { id: 7, nombre: 'Operador 1', email: 'operador1@sistema.com', contraseña: 'ope123', rol: 'operador', fecha_creacion: new Date().toISOString() },
    { id: 8, nombre: 'Operador 2', email: 'operador2@sistema.com', contraseña: 'ope234', rol: 'operador', fecha_creacion: new Date().toISOString() },
    { id: 9, nombre: 'Operador 3', email: 'operador3@sistema.com', contraseña: 'ope345', rol: 'operador', fecha_creacion: new Date().toISOString() },
    { id: 10, nombre: 'Supervisor 2', email: 'supervisor2@sistema.com', contraseña: 'sup234', rol: 'supervisor', fecha_creacion: new Date().toISOString() },
    { id: 11, nombre: 'Soporte 1', email: 'soporte1@sistema.com', contraseña: 'sop123', rol: 'soporte', fecha_creacion: new Date().toISOString() },
    { id: 12, nombre: 'Soporte 2', email: 'soporte2@sistema.com', contraseña: 'sop234', rol: 'soporte', fecha_creacion: new Date().toISOString() },
    { id: 13, nombre: 'Invitado', email: 'invitado@sistema.com', contraseña: 'inv123', rol: 'invitado', fecha_creacion: new Date().toISOString() },
    { id: 14, nombre: 'Auditor', email: 'auditor@sistema.com', contraseña: 'aud123', rol: 'auditor', fecha_creacion: new Date().toISOString() },
    { id: 15, nombre: 'Root', email: 'root@sistema.com', contraseña: 'root123', rol: 'administrador', fecha_creacion: new Date().toISOString() }
];

let equipoCliente = [
  // Cliente 1
  { id: 2, equipo_id: 2, cliente_id: 1, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 1, equipo_id: 1, cliente_id: 1, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 3, equipo_id: 3, cliente_id: 1, fecha_asignacion: new Date().toISOString(), activo: false },

  // Cliente 2
  { id: 4, equipo_id: 4, cliente_id: 2, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 5, equipo_id: 5, cliente_id: 2, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 6, equipo_id: 6, cliente_id: 2, fecha_asignacion: new Date().toISOString(),  activo: false },

  // Cliente 3
  { id: 7, equipo_id: 7, cliente_id: 3, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 8, equipo_id: 8, cliente_id: 3, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 9, equipo_id: 9, cliente_id: 3, fecha_asignacion: new Date().toISOString(),  activo: false },

  // Cliente 4
  { id: 10, equipo_id: 10, cliente_id: 4, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 11, equipo_id: 11, cliente_id: 4, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 12, equipo_id: 12, cliente_id: 4, fecha_asignacion: new Date().toISOString(), activo: false },
  { id: 51, equipo_id: 7, cliente_id: 4, fecha_asignacion: new Date().toISOString(), activo: false },

  // Cliente 5
  { id: 13, equipo_id: 13, cliente_id: 5, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 14, equipo_id: 14, cliente_id: 5, fecha_asignacion: new Date().toISOString(), activo: true },

  // Cliente 6
  { id: 15, equipo_id: 15, cliente_id: 6, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 16, equipo_id: 16, cliente_id: 6, fecha_asignacion: new Date().toISOString(),  activo: true },

  // Cliente 7
  { id: 17, equipo_id: 17, cliente_id: 7, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 18, equipo_id: 18, cliente_id: 7, fecha_asignacion: new Date().toISOString(), activo: true },

  // Cliente 8
  { id: 19, equipo_id: 19, cliente_id: 8, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 20, equipo_id: 20, cliente_id: 8, fecha_asignacion: new Date().toISOString(),  activo: true },

  // Cliente 9
  { id: 21, equipo_id: 21, cliente_id: 9, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 22, equipo_id: 22, cliente_id: 9, fecha_asignacion: new Date().toISOString(),  activo: true },

  // Cliente 10
  { id: 23, equipo_id: 23, cliente_id: 10, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 24, equipo_id: 24, cliente_id: 10, fecha_asignacion: new Date().toISOString(),  activo: true },

  // Cliente 11
  { id: 25, equipo_id: 25, cliente_id: 11, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 26, equipo_id: 26, cliente_id: 11, fecha_asignacion: new Date().toISOString(), activo: true },

  // Cliente 12
  { id: 27, equipo_id: 27, cliente_id: 12, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 28, equipo_id: 28, cliente_id: 12, fecha_asignacion: new Date().toISOString(), activo: true },

  // Cliente 13
  { id: 29, equipo_id: 29, cliente_id: 13, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 30, equipo_id: 30, cliente_id: 13, fecha_asignacion: new Date().toISOString(),  activo: true },

  // Cliente 14
  { id: 31, equipo_id: 31, cliente_id: 14, fecha_asignacion: new Date().toISOString(),  activo: true },
  { id: 32, equipo_id: 32, cliente_id: 14, fecha_asignacion: new Date().toISOString(),  activo: true },

  // Cliente 15
  { id: 33, equipo_id: 33, cliente_id: 15, fecha_asignacion: new Date().toISOString(), activo: true },
  { id: 34, equipo_id: 34, cliente_id: 15, fecha_asignacion: new Date().toISOString(),  activo: true }
];

let censoEquipo = [
    { id: 1, equipo_id: 1, cliente_id: 1, usuario_id: 1, funcionando: true, estado_general: 'Funcionando correctamente', latitud: -25.2637, longitud: -57.5759, fecha_revision: new Date().toISOString() },
    { id: 2, equipo_id: 2, cliente_id: 2, usuario_id: 2, funcionando: false, estado_general: 'Problema de temperatura', latitud: -25.2800, longitud: -57.6300, fecha_revision: new Date().toISOString() },
    { id: 3, equipo_id: 3, cliente_id: 3, usuario_id: 3, funcionando: true, estado_general: 'Óptimas condiciones', latitud: -25.3100, longitud: -57.6000, fecha_revision: new Date().toISOString() },
    { id: 4, equipo_id: 4, cliente_id: 4, usuario_id: 4, funcionando: true, estado_general: 'Funcionando estable', latitud: -25.2950, longitud: -57.5800, fecha_revision: new Date().toISOString() },
    { id: 5, equipo_id: 5, cliente_id: 5, usuario_id: 5, funcionando: false, estado_general: 'Apagado por cliente',latitud: -25.3200, longitud: -57.6100, fecha_revision: new Date().toISOString() },
    { id: 6, equipo_id: 6, cliente_id: 6, usuario_id: 6, funcionando: true, estado_general: 'Sin anomalías', latitud: -25.2805, longitud: -57.5990, fecha_revision: new Date().toISOString() },
    { id: 7, equipo_id: 7, cliente_id: 7, usuario_id: 7, funcionando: true, estado_general: 'Correcto funcionamiento', latitud: -25.2700, longitud: -57.5900, fecha_revision: new Date().toISOString() },
    { id: 8, equipo_id: 8, cliente_id: 8, usuario_id: 8, funcionando: false, estado_general: 'Compresor con fallas', latitud: -25.2650, longitud: -57.5850, fecha_revision: new Date().toISOString() },
    { id: 9, equipo_id: 9, cliente_id: 9, usuario_id: 9, funcionando: true, estado_general: 'Revisión completa',latitud: -25.2750, longitud: -57.5950, fecha_revision: new Date().toISOString() },
    { id: 10, equipo_id: 10, cliente_id: 10, usuario_id: 10, funcionando: true, estado_general: 'Operativo', latitud: -25.2600, longitud: -57.5700, fecha_revision: new Date().toISOString() },
    { id: 11, equipo_id: 11, cliente_id: 11, usuario_id: 11, funcionando: false, estado_general: 'Falla eléctrica', latitud: -25.2850, longitud: -57.6000, fecha_revision: new Date().toISOString() },
    { id: 12, equipo_id: 12, cliente_id: 12, usuario_id: 12, funcionando: true, estado_general: 'Sistema normal', latitud: -25.2955, longitud: -57.6020, fecha_revision: new Date().toISOString() },
    { id: 13, equipo_id: 13, cliente_id: 13, usuario_id: 13, funcionando: true, estado_general: 'Temperatura estable', latitud: -25.2990, longitud: -57.6050, fecha_revision: new Date().toISOString() },
    { id: 14, equipo_id: 14, cliente_id: 14, usuario_id: 14, funcionando: false, estado_general: 'Pérdida de gas refrigerante',latitud: -25.3010, longitud: -57.6070, fecha_revision: new Date().toISOString() },
    { id: 15, equipo_id: 15, cliente_id: 15, usuario_id: 15, funcionando: true, estado_general: 'Sin observaciones',latitud: -25.3050, longitud: -57.6090, fecha_revision: new Date().toISOString() }
];

// ENDPOINTS SIMPLES (estilo original)

// Ping
app.get('/ping', (req, res) => {
    console.log(`📡 Ping recibido - Servidor funcionando`);
    res.json({
        success: true,
        message: 'Servidor funcionando correctamente',
        timestamp: new Date().toISOString(),
        version: '3.1.0'
    });
});

// MODELOS
app.get('/modelos', (req, res) => {
    console.log(`Enviando ${modelo.length} modelos`);
    res.json(modelo);
});

// MARCAS
app.get('/marcas', (req, res) => {
    console.log(`Enviando ${marcas.length} marcas`);
    res.json(marcas);
});

// LOGOS  
app.get('/logo', (req, res) => {
    console.log(`Enviando ${logo.length} logos`);
    res.json(logo);
});

// CLIENTES 
app.get('/clientes', (req, res) => {
    console.log(`📤 Enviando ${clientes.length} clientes`);
    console.log(`📋 Primeros 3 clientes:`, clientes.slice(0, 3).map(c => `${c.nombre} (${c.email})`));
    res.json(clientes);
});

app.post('/clientes', (req, res) => {
    const { nombre, email, telefono, direccion } = req.body;
    
    console.log(`📥 Recibiendo nuevo cliente:`);
    console.log(`   - Nombre: ${nombre}`);
    console.log(`   - Email: ${email}`);
    console.log(`   - Teléfono: ${telefono || 'No especificado'}`);
    console.log(`   - Dirección: ${direccion || 'No especificada'}`);
    
    if (!nombre || !email) {
        console.log(`❌ Error: Datos incompletos`);
        return res.status(400).json({
            success: false,
            message: 'Nombre y email son requeridos'
        });
    }
    
    const nuevoId = Math.max(...clientes.map(c => c.id)) + 1;
    const cliente = {
        id: nuevoId,
        nombre: nombre.trim(),
        email: email.trim().toLowerCase(),
        telefono: telefono || '',
        direccion: direccion || '',
        activo: true,
        fecha_creacion: new Date().toISOString()
    };
    
    clientes.push(cliente);
    console.log(`✅ Cliente creado exitosamente con ID: ${nuevoId}`);
    
    res.status(201).json({
        success: true,
        message: 'Cliente creado correctamente',
        cliente
    });
});

// EQUIPOS - 
app.get('/equipos', (req, res) => {
    console.log(`📤 Enviando ${equipos.length} equipos`);
    console.log(`📋 Primeros 3 equipos:`, equipos.slice(0, 3).map(e => `${e.marca} ${e.modelo} (${e.cod_barras})`));
    res.json(equipos);
});

app.get('/equipos/buscar', (req, res) => {
    const q = req.query.q?.toLowerCase() || '';
    console.log(`🔍 Buscando equipos con término: "${q}"`);
    
    const encontrados = equipos.filter(e =>
        e.cod_barras.toLowerCase().includes(q) || 
        e.marca.toLowerCase().includes(q) ||
        e.modelo.toLowerCase().includes(q)
    );
    
    console.log(`📊 Encontrados ${encontrados.length} equipos`);
    
    res.json({
        success: true,
        equipos: encontrados,
        total: encontrados.length
    });
});

app.post('/equipos', (req, res) => {
    const { cod_barras, marca, modelo, tipo_equipo } = req.body;
    
    console.log(`📥 Recibiendo nuevo equipo:`);
    console.log(`   - Código: ${cod_barras}`);
    console.log(`   - Marca: ${marca}`);
    console.log(`   - Modelo: ${modelo}`);
    console.log(`   - Tipo: ${tipo_equipo}`);
    
    if (!cod_barras || !marca || !modelo || !tipo_equipo) {
        console.log(`❌ Error: Datos incompletos`);
        return res.status(400).json({
            success: false,
            message: 'Todos los campos son requeridos'
        });
    }
    
    if (equipos.find(e => e.cod_barras === cod_barras)) {
        console.log(`❌ Error: Código de barras ya existe`);
        return res.status(400).json({
            success: false,
            message: 'El código de barras ya existe'
        });
    }
    
    const nuevoId = Math.max(...equipos.map(e => e.id)) + 1;
    const equipo = {
        id: nuevoId,
        cod_barras: cod_barras.trim(),
        marca: marca.trim(),
        modelo: modelo.trim(),
        tipo_equipo: tipo_equipo.trim(),
        fecha_creacion: new Date().toISOString()
    };
    
    equipos.push(equipo);
    console.log(`✅ Equipo creado exitosamente con ID: ${nuevoId}`);
    
    res.status(201).json({
        success: true,
        message: 'Equipo creado correctamente',
        equipo
    });
});

// USUARIOS
app.get('/usuarios', (req, res) => {
    const usuariosSinPassword = usuarios.map(u => ({
        id: u.id,
        nombre: u.nombre,
        email: u.email,
        rol: u.rol,
        fecha_creacion: u.fecha_creacion
    }));
    
    console.log(`📤 Enviando ${usuariosSinPassword.length} usuarios (sin contraseñas)`);
    res.json(usuariosSinPassword);
});

app.post('/usuarios/login', (req, res) => {
    const { email, contraseña } = req.body;
    console.log(`🔑 Intento de login para: ${email}`);
    
    const usuario = usuarios.find(u => u.email === email && u.contraseña === contraseña);
    
    if (usuario) {
        console.log(`✅ Login exitoso: ${usuario.nombre} (${usuario.rol})`);
        res.json({
            success: true,
            message: 'Login exitoso',
            usuario: {
                id: usuario.id,
                nombre: usuario.nombre,
                email: usuario.email,
                rol: usuario.rol
            }
        });
    } else {
        console.log(`❌ Login fallido para: ${email}`);
        res.status(401).json({
            success: false,
            message: 'Credenciales incorrectas'
        });
    }
});

// ASIGNACIONES - Simple, solo datos básicos para Flutter
app.get('/asignaciones', (req, res) => {
    console.log(`📤 Enviando ${equipoCliente.length} asignaciones (datos básicos)`);
    console.log(`📋 Primeras 3 asignaciones:`, equipoCliente.slice(0, 3).map(ec => 
        `Equipo ${ec.equipo_id} → Cliente ${ec.cliente_id} (${ec.activo ? 'Activo' : 'Inactivo'})`
    ));
    
    // Enviar solo datos básicos sin enriquecer (para que funcione con Flutter)
    res.json(equipoCliente);
});

app.post('/asignaciones', (req, res) => {
    const { equipo_id, cliente_id, usuario_id } = req.body;
    
    console.log(`📥 Nueva asignación:`);
    console.log(`   - Equipo ID: ${equipo_id}`);
    console.log(`   - Cliente ID: ${cliente_id}`);
    console.log(`   - Usuario ID: ${usuario_id}`);
    
    if (!equipo_id || !cliente_id || !usuario_id) {
        console.log(`❌ Error: IDs incompletos`);
        return res.status(400).json({
            success: false,
            message: 'Todos los IDs son requeridos'
        });
    }
    
    const equipo = equipos.find(e => e.id === parseInt(equipo_id));
    const cliente = clientes.find(c => c.id === parseInt(cliente_id));
    const usuario = usuarios.find(u => u.id === parseInt(usuario_id));
    
    if (!equipo || !cliente || !usuario) {
        console.log(`❌ Error: Equipo, cliente o usuario no encontrado`);
        return res.status(400).json({
            success: false,
            message: 'Equipo, cliente o usuario no encontrado'
        });
    }
    
    const yaAsignado = equipoCliente.find(ec => ec.equipo_id === parseInt(equipo_id) && ec.activo);
    if (yaAsignado) {
        console.log(`❌ Error: Equipo ya asignado`);
        return res.status(400).json({
            success: false,
            message: 'El equipo ya está asignado'
        });
    }
    
    // Crear asignación
    const nuevaAsignacionId = Math.max(...equipoCliente.map(ec => ec.id)) + 1;
    const asignacion = {
        id: nuevaAsignacionId,
        equipo_id: parseInt(equipo_id),
        cliente_id: parseInt(cliente_id),
        fecha_asignacion: new Date().toISOString(),
        fecha_retiro: null,
        activo: true
    };
    
    // Crear estado inicial
    const nuevoEstadoId = Math.max(...estadoEquipo.map(ee => ee.id)) + 1;
    const estado = {
        id: nuevoEstadoId,
        equipo_id: parseInt(equipo_id),
        cliente_id: parseInt(cliente_id),
        usuario_id: parseInt(usuario_id),
        funcionando: true,
        estado_general: 'Asignado - Pendiente revisión',
        temperatura_actual: null,
        temperatura_freezer: null,
        latitud: -25.2637,
        longitud: -57.5759,
        fecha_revision: new Date().toISOString()
    };
    
    equipoCliente.push(asignacion);
    estadoEquipo.push(estado);
    
    console.log(`✅ Asignación creada: ${equipo.marca} ${equipo.modelo} → ${cliente.nombre}`);
    
    res.status(201).json({
        success: true,
        message: 'Asignación creada correctamente',
        asignacion,
        estado
    });
});

// ESTADOS
app.get('/estados', (req, res) => {
    console.log(`📤 Enviando ${estadoEquipo.length} estados de equipos`);
    console.log(`📋 Primeros 3 estados:`, estadoEquipo.slice(0, 3).map(ee => 
        `Equipo ${ee.equipo_id}: ${ee.estado_general} (${ee.funcionando ? 'OK' : 'FALLA'})`
    ));
    res.json(estadoEquipo);
});

app.post('/estados', (req, res) => {
    const { equipo_id, cliente_id, usuario_id, funcionando, estado_general, temperatura_actual, temperatura_freezer, latitud, longitud } = req.body;
    
    console.log(`📥 Nuevo estado de equipo:`);
    console.log(`   - Equipo ID: ${equipo_id}`);
    console.log(`   - Cliente ID: ${cliente_id}`);
    console.log(`   - Usuario ID: ${usuario_id}`);
    console.log(`   - Funcionando: ${funcionando ? 'SÍ' : 'NO'}`);
    console.log(`   - Estado: ${estado_general}`);
    console.log(`   - Temperatura: ${temperatura_actual}°C / Freezer: ${temperatura_freezer}°C`);
    
    if (!equipo_id || !cliente_id || !usuario_id || funcionando === undefined || !estado_general) {
        console.log(`❌ Error: Datos incompletos`);
        return res.status(400).json({
            success: false,
            message: 'Datos incompletos'
        });
    }
    
    const nuevoId = Math.max(...estadoEquipo.map(ee => ee.id)) + 1;
    const estado = {
        id: nuevoId,
        equipo_id: parseInt(equipo_id),
        cliente_id: parseInt(cliente_id),
        usuario_id: parseInt(usuario_id),
        funcionando,
        estado_general,
        temperatura_actual: temperatura_actual || null,
        temperatura_freezer: temperatura_freezer || null,
        latitud: latitud || -25.2637,
        longitud: longitud || -57.5759,
        fecha_revision: new Date().toISOString()
    };
    
    estadoEquipo.push(estado);
    console.log(`✅ Estado actualizado para equipo ${equipo_id}`);
    
    res.status(201).json({
        success: true,
        message: 'Estado actualizado correctamente',
        estado
    });
});

// DASHBOARD
app.get('/dashboard', (req, res) => {
    const equiposAsignados = equipoCliente.filter(ec => ec.activo).length;
    const equiposFuncionando = estadoEquipo.filter(ee => ee.funcionando).length;
    
    const estadisticas = {
        clientes: {
            total: clientes.length,
            activos: clientes.filter(c => c.activo).length
        },
        refrigeradores: {
            total: equipos.length,
            asignados: equiposAsignados,
            libres: equipos.length - equiposAsignados,
            funcionando: equiposFuncionando,
            en_reparacion: estadoEquipo.filter(ee => !ee.funcionando).length
        },
        usuarios: {
            total: usuarios.length
        },
        timestamp: new Date().toISOString()
    };
    
    console.log(`📊 Enviando estadísticas del dashboard:`);
    console.log(`   - ${estadisticas.clientes.total} clientes (${estadisticas.clientes.activos} activos)`);
    console.log(`   - ${estadisticas.refrigeradores.total} equipos (${estadisticas.refrigeradores.asignados} asignados)`);
    console.log(`   - ${estadisticas.refrigeradores.funcionando} funcionando, ${estadisticas.refrigeradores.en_reparacion} en reparación`);
    
    res.json(estadisticas);
});

// Error handling
app.use((err, req, res, next) => {
    console.error('💥 Error interno:', err.message);
    res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
    });
});

// 404
app.use((req, res) => {
    console.log(`❓ Ruta no encontrada: ${req.method} ${req.url}`);
    res.status(404).json({
        success: false,
        message: `Ruta no encontrada: ${req.method} ${req.url}`
    });
});

// INICIAR SERVIDOR
const PORT = 3000;
const HOST = '0.0.0.0';

app.listen(PORT, HOST, () => {
    console.clear();
    console.log('\n❄️ SISTEMA DE REFRIGERADORES - API ESTILO ORIGINAL ❄️');
    console.log('═'.repeat(55));
    console.log(`🌐 URL: http://192.168.1.185:${PORT}`);
    console.log(`📊 Datos cargados:`);
    console.log(`   📋 ${clientes.length} clientes`);
    console.log(`   🔧 ${equipos.length} equipos`);
    console.log(`   👥 ${usuarios.length} usuarios`);
    console.log(`   🔗 ${equipoCliente.length} asignaciones`);
    //console.log(`   📈 ${estadoEquipo.length} estados`);
    console.log('✅ Servidor listo para peticiones con logging detallado\n');
});