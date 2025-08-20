const express = require('express');
const cors = require('cors');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Logging middleware
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

let equipos = [
    { id: 1, cod_barras: 'REF001', marca: 'Samsung', modelo: 'RT38K5932SL', tipo_equipo: 'Refrigerador No Frost', fecha_creacion: new Date().toISOString() },
    { id: 2, cod_barras: 'REF002', marca: 'LG', modelo: 'GS65SPP1', tipo_equipo: 'Refrigerador Side by Side', fecha_creacion: new Date().toISOString() },
    { id: 3, cod_barras: 'REF003', marca: 'Whirlpool', modelo: 'WRM35AKTWW', tipo_equipo: 'Refrigerador Convencional', fecha_creacion: new Date().toISOString() },
    { id: 4, cod_barras: 'REF004', marca: 'Electrolux', modelo: 'DF35', tipo_equipo: 'Freezer Vertical', fecha_creacion: new Date().toISOString() },
    { id: 5, cod_barras: 'REF005', marca: 'Panasonic', modelo: 'NR-BL389', tipo_equipo: 'Refrigerador Inverter', fecha_creacion: new Date().toISOString() },
    { id: 6, cod_barras: 'REF006', marca: 'Midea', modelo: 'HS-384', tipo_equipo: 'Freezer Horizontal', fecha_creacion: new Date().toISOString() },
    { id: 7, cod_barras: 'REF007', marca: 'Bosch', modelo: 'KSV36VI3P', tipo_equipo: 'Refrigerador Inteligente', fecha_creacion: new Date().toISOString() },
    { id: 8, cod_barras: 'REF008', marca: 'Daewoo', modelo: 'FRS-U20', tipo_equipo: 'Refrigerador Side by Side', fecha_creacion: new Date().toISOString() },
    { id: 9, cod_barras: 'REF009', marca: 'GE', modelo: 'GTS18', tipo_equipo: 'Refrigerador Convencional', fecha_creacion: new Date().toISOString() },
    { id: 10, cod_barras: 'REF010', marca: 'Sharp', modelo: 'SJ-FS85', tipo_equipo: 'Refrigerador No Frost', fecha_creacion: new Date().toISOString() },
    { id: 11, cod_barras: 'REF011', marca: 'Samsung', modelo: 'RB29HSR2DWW', tipo_equipo: 'Refrigerador Inverter', fecha_creacion: new Date().toISOString() },
    { id: 12, cod_barras: 'REF012', marca: 'LG', modelo: 'GC-X247', tipo_equipo: 'Refrigerador Door-in-Door', fecha_creacion: new Date().toISOString() },
    { id: 13, cod_barras: 'REF013', marca: 'Whirlpool', modelo: 'WRF535SMHZ', tipo_equipo: 'French Door', fecha_creacion: new Date().toISOString() },
    { id: 14, cod_barras: 'REF014', marca: 'Electrolux', modelo: 'TF39', tipo_equipo: 'Refrigerador Convencional', fecha_creacion: new Date().toISOString() },
    { id: 15, cod_barras: 'REF015', marca: 'Panasonic', modelo: 'NR-BY602', tipo_equipo: 'Refrigerador No Frost', fecha_creacion: new Date().toISOString() }
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
    { id: 1, equipo_id: 1, cliente_id: 1, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 2, equipo_id: 2, cliente_id: 2, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 3, equipo_id: 3, cliente_id: 3, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 4, equipo_id: 4, cliente_id: 4, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 5, equipo_id: 5, cliente_id: 5, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: false },
    { id: 6, equipo_id: 6, cliente_id: 6, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 7, equipo_id: 7, cliente_id: 7, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 8, equipo_id: 8, cliente_id: 8, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 9, equipo_id: 9, cliente_id: 9, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 10, equipo_id: 10, cliente_id: 10, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 11, equipo_id: 11, cliente_id: 11, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: false },
    { id: 12, equipo_id: 12, cliente_id: 12, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 13, equipo_id: 13, cliente_id: 13, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 14, equipo_id: 14, cliente_id: 14, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true },
    { id: 15, equipo_id: 15, cliente_id: 15, fecha_asignacion: new Date().toISOString(), fecha_retiro: null, activo: true }
];

let estadoEquipo = [
    { id: 1, equipo_id: 1, cliente_id: 1, usuario_id: 1, funcionando: true, estado_general: 'Funcionando correctamente', temperatura_actual: 4.2, temperatura_freezer: -18.5, latitud: -25.2637, longitud: -57.5759, fecha_revision: new Date().toISOString() },
    { id: 2, equipo_id: 2, cliente_id: 2, usuario_id: 2, funcionando: false, estado_general: 'Problema de temperatura', temperatura_actual: 8.5, temperatura_freezer: -12.0, latitud: -25.2800, longitud: -57.6300, fecha_revision: new Date().toISOString() },
    { id: 3, equipo_id: 3, cliente_id: 3, usuario_id: 3, funcionando: true, estado_general: 'Óptimas condiciones', temperatura_actual: 3.9, temperatura_freezer: -19.1, latitud: -25.3100, longitud: -57.6000, fecha_revision: new Date().toISOString() },
    { id: 4, equipo_id: 4, cliente_id: 4, usuario_id: 4, funcionando: true, estado_general: 'Funcionando estable', temperatura_actual: 5.0, temperatura_freezer: -17.0, latitud: -25.2950, longitud: -57.5800, fecha_revision: new Date().toISOString() },
    { id: 5, equipo_id: 5, cliente_id: 5, usuario_id: 5, funcionando: false, estado_general: 'Apagado por cliente', temperatura_actual: null, temperatura_freezer: null, latitud: -25.3200, longitud: -57.6100, fecha_revision: new Date().toISOString() },
    { id: 6, equipo_id: 6, cliente_id: 6, usuario_id: 6, funcionando: true, estado_general: 'Sin anomalías', temperatura_actual: 4.5, temperatura_freezer: -18.2, latitud: -25.2805, longitud: -57.5990, fecha_revision: new Date().toISOString() },
    { id: 7, equipo_id: 7, cliente_id: 7, usuario_id: 7, funcionando: true, estado_general: 'Correcto funcionamiento', temperatura_actual: 4.0, temperatura_freezer: -18.0, latitud: -25.2700, longitud: -57.5900, fecha_revision: new Date().toISOString() },
    { id: 8, equipo_id: 8, cliente_id: 8, usuario_id: 8, funcionando: false, estado_general: 'Compresor con fallas', temperatura_actual: 10.0, temperatura_freezer: -8.0, latitud: -25.2650, longitud: -57.5850, fecha_revision: new Date().toISOString() },
    { id: 9, equipo_id: 9, cliente_id: 9, usuario_id: 9, funcionando: true, estado_general: 'Revisión completa', temperatura_actual: 3.5, temperatura_freezer: -19.0, latitud: -25.2750, longitud: -57.5950, fecha_revision: new Date().toISOString() },
    { id: 10, equipo_id: 10, cliente_id: 10, usuario_id: 10, funcionando: true, estado_general: 'Operativo', temperatura_actual: 4.1, temperatura_freezer: -18.4, latitud: -25.2600, longitud: -57.5700, fecha_revision: new Date().toISOString() },
    { id: 11, equipo_id: 11, cliente_id: 11, usuario_id: 11, funcionando: false, estado_general: 'Falla eléctrica', temperatura_actual: null, temperatura_freezer: null, latitud: -25.2850, longitud: -57.6000, fecha_revision: new Date().toISOString() },
    { id: 12, equipo_id: 12, cliente_id: 12, usuario_id: 12, funcionando: true, estado_general: 'Sistema normal', temperatura_actual: 3.8, temperatura_freezer: -19.2, latitud: -25.2955, longitud: -57.6020, fecha_revision: new Date().toISOString() },
    { id: 13, equipo_id: 13, cliente_id: 13, usuario_id: 13, funcionando: true, estado_general: 'Temperatura estable', temperatura_actual: 4.3, temperatura_freezer: -18.3, latitud: -25.2990, longitud: -57.6050, fecha_revision: new Date().toISOString() },
    { id: 14, equipo_id: 14, cliente_id: 14, usuario_id: 14, funcionando: false, estado_general: 'Pérdida de gas refrigerante', temperatura_actual: 12.0, temperatura_freezer: -5.0, latitud: -25.3010, longitud: -57.6070, fecha_revision: new Date().toISOString() },
    { id: 15, equipo_id: 15, cliente_id: 15, usuario_id: 15, funcionando: true, estado_general: 'Sin observaciones', temperatura_actual: 4.0, temperatura_freezer: -18.0, latitud: -25.3050, longitud: -57.6090, fecha_revision: new Date().toISOString() }
];


// ENDPOINTS

// Ping
app.get('/ping', (req, res) => {
    res.json({
        success: true,
        message: 'Servidor funcionando correctamente',
        timestamp: new Date().toISOString(),
        version: '3.0.0'
    });
});

// CLIENTES
app.get('/clientes', (req, res) => {
    console.log(`Enviando ${clientes.length} clientes`);
    res.json(clientes);
});

app.post('/clientes', (req, res) => {
    const { nombre, email, telefono, direccion } = req.body;
    
    if (!nombre || !email) {
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
    console.log(`Cliente creado: ${cliente.nombre}`);
    
    res.status(201).json({
        success: true,
        message: 'Cliente creado correctamente',
        cliente
    });
});

// EQUIPOS
app.get('/equipos', (req, res) => {
    const equiposConInfo = equipos.map(equipo => {
        const asignacion = equipoCliente.find(ec => ec.equipo_id === equipo.id && ec.activo);
        const cliente = asignacion ? clientes.find(c => c.id === asignacion.cliente_id) : null;
        const estado = estadoEquipo.find(ee => ee.equipo_id === equipo.id);
        
        return {
            ...equipo,
            asignado_a: cliente ? cliente.nombre : null,
            cliente_id: cliente ? cliente.id : null,
            estado_actual: estado ? estado.estado_general : 'Sin revisar',
            funcionando: estado ? estado.funcionando : null,
            temperatura_actual: estado ? estado.temperatura_actual : null,
            temperatura_freezer: estado ? estado.temperatura_freezer : null
        };
    });
    
    console.log(`Enviando ${equiposConInfo.length} equipos`);
    res.json(equiposConInfo);
});

app.get('/equipos/buscar', (req, res) => {
    const q = req.query.q?.toLowerCase() || '';
    const encontrados = equipos.filter(e =>
        e.cod_barras.toLowerCase().includes(q) || 
        e.marca.toLowerCase().includes(q) ||
        e.modelo.toLowerCase().includes(q)
    );
    
    res.json({
        success: true,
        equipos: encontrados,
        total: encontrados.length
    });
});

app.post('/equipos', (req, res) => {
    const { cod_barras, marca, modelo, tipo_equipo } = req.body;
    
    if (!cod_barras || !marca || !modelo || !tipo_equipo) {
        return res.status(400).json({
            success: false,
            message: 'Todos los campos son requeridos'
        });
    }
    
    if (equipos.find(e => e.cod_barras === cod_barras)) {
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
    console.log(`Equipo creado: ${equipo.marca} ${equipo.modelo}`);
    
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
    
    res.json(usuariosSinPassword);
});

app.post('/usuarios/login', (req, res) => {
    const { email, contraseña } = req.body;
    const usuario = usuarios.find(u => u.email === email && u.contraseña === contraseña);
    
    if (usuario) {
        console.log(`Login exitoso: ${usuario.nombre}`);
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
        console.log('Login fallido');
        res.status(401).json({
            success: false,
            message: 'Credenciales incorrectas'
        });
    }
});

// ASIGNACIONES
app.get('/asignaciones', (req, res) => {
    const asignaciones = equipoCliente
        .filter(ec => ec.activo)
        .map(asignacion => {
            const equipo = equipos.find(e => e.id === asignacion.equipo_id);
            const cliente = clientes.find(c => c.id === asignacion.cliente_id);
            const estado = estadoEquipo.find(ee => ee.equipo_id === asignacion.equipo_id);
            
            return {
                id: asignacion.id,
                refrigerador: equipo ? `${equipo.marca} ${equipo.modelo}` : 'No encontrado',
                cliente: cliente ? cliente.nombre : 'No encontrado',
                equipo_id: asignacion.equipo_id,
                cliente_id: asignacion.cliente_id,
                fecha_asignacion: asignacion.fecha_asignacion,
                estado_actual: estado ? estado.estado_general : 'Sin estado',
                funcionando: estado ? estado.funcionando : null,
                temperatura_actual: estado ? estado.temperatura_actual : null
            };
        });
    
    res.json(asignaciones);
});

app.post('/asignaciones', (req, res) => {
    const { equipo_id, cliente_id, usuario_id } = req.body;
    
    if (!equipo_id || !cliente_id || !usuario_id) {
        return res.status(400).json({
            success: false,
            message: 'Todos los IDs son requeridos'
        });
    }
    
    const equipo = equipos.find(e => e.id === parseInt(equipo_id));
    const cliente = clientes.find(c => c.id === parseInt(cliente_id));
    const usuario = usuarios.find(u => u.id === parseInt(usuario_id));
    
    if (!equipo || !cliente || !usuario) {
        return res.status(400).json({
            success: false,
            message: 'Equipo, cliente o usuario no encontrado'
        });
    }
    
    const yaAsignado = equipoCliente.find(ec => ec.equipo_id === parseInt(equipo_id) && ec.activo);
    if (yaAsignado) {
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
    
    console.log(`Asignación creada: ${equipo.marca} → ${cliente.nombre}`);
    
    res.status(201).json({
        success: true,
        message: 'Asignación creada correctamente',
        asignacion,
        estado
    });
});

// ESTADOS
app.get('/estados', (req, res) => {
    const estados = estadoEquipo.map(estado => {
        const equipo = equipos.find(e => e.id === estado.equipo_id);
        const cliente = clientes.find(c => c.id === estado.cliente_id);
        const usuario = usuarios.find(u => u.id === estado.usuario_id);
        
        return {
            ...estado,
            refrigerador_info: equipo ? `${equipo.marca} ${equipo.modelo}` : 'No encontrado',
            cliente_nombre: cliente ? cliente.nombre : 'No encontrado',
            usuario_nombre: usuario ? usuario.nombre : 'No encontrado'
        };
    });
    
    res.json(estados);
});

app.post('/estados', (req, res) => {
    const { equipo_id, cliente_id, usuario_id, funcionando, estado_general, temperatura_actual, temperatura_freezer, latitud, longitud } = req.body;
    
    if (!equipo_id || !cliente_id || !usuario_id || funcionando === undefined || !estado_general) {
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
    console.log(`Estado actualizado para equipo ${equipo_id}`);
    
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
    
    res.json(estadisticas);
});

// Error handling
app.use((err, req, res, next) => {
    console.error('Error:', err.message);
    res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
    });
});

// 404
app.use((req, res) => {
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
    console.log('\n❄️ SISTEMA DE REFRIGERADORES - API INICIADA ❄️');
    console.log('═'.repeat(50));
    console.log(`🌐 URL: http://192.168.100.128:${PORT}`);
    console.log(`📊 Datos: ${clientes.length} clientes, ${equipos.length} equipos`);
    console.log('✅ Servidor listo para peticiones\n');
});