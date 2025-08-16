const express = require('express');
const cors = require('cors');

const app = express();

// Middleware básico
app.use(cors());
app.use(express.json());

// 📊 MIDDLEWARE DE LOGGING DETALLADO
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    const localTime = new Date().toLocaleString('es-PY', { 
        timeZone: 'America/Asuncion',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
    
    console.log('\n' + '='.repeat(80));
    console.log(`📡 PETICIÓN RECIBIDA [${localTime}]`);
    console.log('='.repeat(80));
    console.log(`🔍 Método: ${req.method}`);
    console.log(`📍 URL: ${req.url}`);
    console.log(`🌍 IP Cliente: ${req.ip || req.connection.remoteAddress}`);
    console.log(`🖥️  User-Agent: ${req.headers['user-agent']?.substring(0, 50) || 'No especificado'}...`);
    
    // Log de headers importantes
    console.log('\n📋 HEADERS IMPORTANTES:');
    console.log(`   Content-Type: ${req.headers['content-type'] || 'No especificado'}`);
    console.log(`   Content-Length: ${req.headers['content-length'] || 'No especificado'}`);
    console.log(`   Accept: ${req.headers['accept']?.substring(0, 50) || 'No especificado'}...`);
    
    // Log de query parameters
    if (req.query && Object.keys(req.query).length > 0) {
        console.log('\n🔍 QUERY PARAMETERS:');
        Object.entries(req.query).forEach(([key, value]) => {
            console.log(`   ${key}: ${value}`);
        });
    }
    
    // Log del body (datos enviados)
    if (req.body && Object.keys(req.body).length > 0) {
        console.log('\n📦 DATOS RECIBIDOS (BODY):');
        console.log('┌' + '─'.repeat(78) + '┐');
        
        if (req.method === 'POST' || req.method === 'PUT') {
            console.log('│ 🎯 DATOS ENVIADOS DESDE FLUTTER:');
            console.log('│');
            
            try {
                const bodyStr = JSON.stringify(req.body, null, 2);
                const lines = bodyStr.split('\n');
                lines.forEach(line => {
                    console.log(`│ ${line.padEnd(76)} │`);
                });
            } catch (error) {
                console.log('│ Error al mostrar el body:', error.message);
            }
        }
        
        console.log('└' + '─'.repeat(78) + '┘');
    }
    
    console.log('\n⏳ Procesando petición...');
    
    // Capturar la respuesta para logging
    const originalSend = res.send;
    res.send = function(data) {
        console.log('\n📤 RESPUESTA ENVIADA:');
        console.log(`   Status: ${res.statusCode}`);
        console.log(`   Tamaño: ${Buffer.byteLength(data)} bytes`);
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log(`   ✅ Éxito: ${res.statusCode}`);
        } else if (res.statusCode >= 400) {
            console.log(`   ❌ Error: ${res.statusCode}`);
        }
        
        console.log('='.repeat(80));
        
        originalSend.call(this, data);
    };
    
    next();
});

// 🎯 DATOS DE EJEMPLO - Lista amplia de clientes
let clientes = [
    { id: 1, nombre: 'Juan Pérez', email: 'juan@email.com', telefono: '0981-123456', direccion: 'Asunción, Paraguay', fecha_creacion: new Date().toISOString() },
    { id: 2, nombre: 'María García', email: 'maria@email.com', telefono: '0984-654321', direccion: 'Luque, Paraguay', fecha_creacion: new Date().toISOString() },
    { id: 3, nombre: 'Carlos López', email: 'carlos@email.com', telefono: '0985-789123', direccion: 'San Lorenzo, Paraguay', fecha_creacion: new Date().toISOString() },
    { id: 4, nombre: 'Ronaldo Rebollo', email: 'ronaldo@email.com', telefono: '0986-987654', direccion: 'Fernando de la Mora', fecha_creacion: new Date().toISOString() },
    { id: 5, nombre: 'Ana Martínez', email: 'ana@email.com', telefono: '0987-112233', direccion: 'San Lorenzo', fecha_creacion: new Date().toISOString() },
    { id: 6, nombre: 'Pedro Fernández', email: 'pedro@email.com', telefono: '0988-445566', direccion: 'Luque', fecha_creacion: new Date().toISOString() },
    { id: 7, nombre: 'Lucía Gómez', email: 'lucia@email.com', telefono: '0989-778899', direccion: 'Asunción', fecha_creacion: new Date().toISOString() },
    { id: 8, nombre: 'Diego Ramírez', email: 'diego@email.com', telefono: '0990-223344', direccion: 'San Lorenzo', fecha_creacion: new Date().toISOString() },
    { id: 9, nombre: 'Sofía Torres', email: 'sofia@email.com', telefono: '0991-556677', direccion: 'Luque', fecha_creacion: new Date().toISOString() },
    { id: 10, nombre: 'Miguel Díaz', email: 'miguel@email.com', telefono: '0992-889900', direccion: 'Asunción', fecha_creacion: new Date().toISOString() },
    { id: 11, nombre: 'Valentina Ríos', email: 'valentina@email.com', telefono: '0993-111222', direccion: 'Capiatá', fecha_creacion: new Date().toISOString() },
    { id: 12, nombre: 'Javier Medina', email: 'javier@email.com', telefono: '0994-333444', direccion: 'Asunción', fecha_creacion: new Date().toISOString() },
    { id: 13, nombre: 'Camila Sánchez', email: 'camila@email.com', telefono: '0995-555666', direccion: 'Luque', fecha_creacion: new Date().toISOString() },
    { id: 14, nombre: 'Andrés Villalba', email: 'andres@email.com', telefono: '0996-777888', direccion: 'San Lorenzo', fecha_creacion: new Date().toISOString() },
    { id: 15, nombre: 'Laura Duarte', email: 'laura@email.com', telefono: '0997-999000', direccion: 'Fernando de la Mora', fecha_creacion: new Date().toISOString() },
    { id: 16, nombre: 'Gonzalo Torres', email: 'gonzalo@email.com', telefono: '0998-111333', direccion: 'Capiatá', fecha_creacion: new Date().toISOString() },
    { id: 17, nombre: 'Paola Giménez', email: 'paola@email.com', telefono: '0999-444555', direccion: 'Lambaré', fecha_creacion: new Date().toISOString() },
    { id: 18, nombre: 'Martín Benítez', email: 'martin@email.com', telefono: '0971-666777', direccion: 'Asunción', fecha_creacion: new Date().toISOString() },
    { id: 19, nombre: 'Florencia Caballero', email: 'florencia@email.com', telefono: '0972-888999', direccion: 'San Lorenzo', fecha_creacion: new Date().toISOString() },
    { id: 20, nombre: 'Hernán Vera', email: 'hernan@email.com', telefono: '0973-000111', direccion: 'Luque', fecha_creacion: new Date().toISOString() },
    { id: 21, nombre: 'Daniela López', email: 'daniela@email.com', telefono: '0974-222333', direccion: 'Asunción', fecha_creacion: new Date().toISOString() },
    { id: 22, nombre: 'Sebastián Acosta', email: 'sebastian@email.com', telefono: '0975-444555', direccion: 'Capiatá', fecha_creacion: new Date().toISOString() },
    { id: 23, nombre: 'Natalia Rojas', email: 'natalia@email.com', telefono: '0976-666777', direccion: 'San Lorenzo', fecha_creacion: new Date().toISOString() },
    { id: 24, nombre: 'Pablo Martínez', email: 'pablo@email.com', telefono: '0977-888999', direccion: 'Fernando de la Mora', fecha_creacion: new Date().toISOString() },
    { id: 25, nombre: 'Marisol Cáceres', email: 'marisol@email.com', telefono: '0978-000111', direccion: 'Luque', fecha_creacion: new Date().toISOString() },
    { id: 26, nombre: 'Rodrigo Ayala', email: 'rodrigo@email.com', telefono: '0979-222333', direccion: 'Lambaré', fecha_creacion: new Date().toISOString() },
    { id: 27, nombre: 'Isabel Franco', email: 'isabel@email.com', telefono: '0961-444555', direccion: 'Asunción', fecha_creacion: new Date().toISOString() },
    { id: 28, nombre: 'Federico Ortiz', email: 'federico@email.com', telefono: '0962-666777', direccion: 'San Lorenzo', fecha_creacion: new Date().toISOString() },
    { id: 29, nombre: 'Gabriela Núñez', email: 'gabriela@email.com', telefono: '0963-888999', direccion: 'Luque', fecha_creacion: new Date().toISOString() },
    { id: 30, nombre: 'Tomás González', email: 'tomas@email.com', telefono: '0964-000111', direccion: 'Capiatá', fecha_creacion: new Date().toISOString() }
];

// 🏓 GET /ping - Verificar conexión
app.get('/ping', (req, res) => {
    console.log('\n🏓 PING - Verificando conexión...');
    console.log('✅ Servidor funcionando correctamente');
    
    res.json({
        success: true,
        message: 'Servidor Node.js funcionando correctamente',
        timestamp: new Date().toISOString(),
        uptime: Math.floor(process.uptime()),
        version: '2.0.0',
        servidor: 'Node.js + Express'
    });
});

// 📋 GET /clientes - Obtener todos los clientes con paginación
app.get('/clientes', (req, res) => {
    console.log('\n📋 GET /clientes - Obteniendo lista de clientes...');
    
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 1000; // Alto por defecto para obtener todos
    
    console.log(`   📄 Página solicitada: ${page}`);
    console.log(`   📊 Límite por página: ${limit}`);
    console.log(`   📈 Total de clientes en BD: ${clientes.length}`);

    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;

    const resultados = clientes.slice(startIndex, endIndex);
    
    console.log(`   📤 Enviando ${resultados.length} clientes`);
    console.log(`   📍 Índices: ${startIndex} - ${endIndex}`);

    // Respuesta compatible con ambos formatos
    res.json(resultados); // Array directo para compatibilidad con Flutter
});

// 🔍 GET /clientes/buscar - Buscar clientes por nombre o email
app.get('/clientes/buscar', (req, res) => {
    const q = req.query.q?.toLowerCase() || '';
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;

    console.log('\n🔍 BÚSQUEDA DE CLIENTES:');
    console.log(`   🔤 Término de búsqueda: "${q}"`);
    console.log(`   📄 Página: ${page}`);
    console.log(`   📊 Límite: ${limit}`);

    const encontrados = clientes.filter(c =>
        c.nombre.toLowerCase().includes(q) || 
        c.email.toLowerCase().includes(q) ||
        (c.telefono && c.telefono.toLowerCase().includes(q))
    );

    console.log(`   🎯 Resultados encontrados: ${encontrados.length}`);

    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const resultados = encontrados.slice(startIndex, endIndex);

    console.log(`   📤 Enviando ${resultados.length} resultados`);

    res.json({
        exito: true,
        mensaje: `Búsqueda completada - ${resultados.length} resultados encontrados`,
        clientes: resultados,
        total: encontrados.length,
        page: page,
        totalPaginas: Math.ceil(encontrados.length / limit),
        query: req.query.q
    });
});

// ➕ POST /clientes - Crear un nuevo cliente (ENDPOINT PRINCIPAL)
app.post('/clientes', (req, res) => {
    console.log('\n' + '🎯'.repeat(40));
    console.log('🎯 ¡CLIENTE RECIBIDO DESDE FLUTTER!');
    console.log('🎯'.repeat(40));
    
    const cliente = req.body;
    
    // Log detallado del cliente recibido
    console.log('\n📋 ANÁLISIS DETALLADO DE DATOS RECIBIDOS:');
    console.log('┌─────────────────────────────────────────────┐');
    console.log(`│ 🆔 ID:         ${String(cliente.id || 'No especificado').padEnd(25)} │`);
    console.log(`│ 👤 Nombre:     ${String(cliente.nombre || '').padEnd(25)} │`);
    console.log(`│ 📧 Email:      ${String(cliente.email || '').padEnd(25)} │`);
    console.log(`│ 📞 Teléfono:   ${String(cliente.telefono || 'No especificado').padEnd(25)} │`);
    console.log(`│ 🏠 Dirección:  ${String(cliente.direccion || 'No especificado').padEnd(25)} │`);
    console.log(`│ 📅 Fecha:      ${String(cliente.fechaCreacion || 'No especificado').padEnd(25)} │`);
    console.log('└─────────────────────────────────────────────┘');
    
    // Validación de datos
    const errores = [];
    if (!cliente.nombre || cliente.nombre.trim() === '') errores.push('Nombre es requerido');
    if (!cliente.email || cliente.email.trim() === '') errores.push('Email es requerido');
    if (cliente.email && !cliente.email.includes('@')) errores.push('Email debe tener formato válido');
    
    if (errores.length > 0) {
        console.log('\n❌ ERRORES DE VALIDACIÓN:');
        errores.forEach((error, index) => {
            console.log(`   ${index + 1}. ${error}`);
        });
        
        return res.status(400).json({
            success: false,
            message: 'Datos incompletos o inválidos',
            errors: errores,
            error: 'DATOS_INCOMPLETOS'
        });
    }
    
    // Generar nuevo ID
    const nuevoId = Math.max(...clientes.map(c => c.id)) + 1;
    
    // Crear cliente procesado
    const clienteGuardado = {
        id: nuevoId,
        nombre: cliente.nombre.trim(),
        email: cliente.email.trim().toLowerCase(),
        telefono: cliente.telefono?.trim() || '',
        direccion: cliente.direccion?.trim() || '',
        fecha_creacion: new Date().toISOString(),
        fechaGuardado: new Date().toISOString(),
        estado: 'GUARDADO'
    };
    
    // Guardar en la "base de datos" (array)
    clientes.push(clienteGuardado);
    
    console.log('\n💾 CLIENTE PROCESADO Y GUARDADO:');
    console.log('┌─────────────────────────────────────────────┐');
    console.log(`│ ✅ Cliente guardado correctamente           │`);
    console.log(`│ 🆔 Nuevo ID asignado: ${String(nuevoId).padEnd(18)} │`);
    console.log(`│ 📊 Total clientes en BD: ${String(clientes.length).padEnd(14)} │`);
    console.log(`│ 🕒 Guardado en: ${new Date().toLocaleTimeString('es-PY').padEnd(19)} │`);
    console.log('└─────────────────────────────────────────────┘');
    
    console.log('\n🎉 Enviando confirmación a Flutter...');
    console.log('🎯'.repeat(40));
    
    // Respuesta exitosa
    res.status(201).json({
        success: true,
        message: 'Cliente recibido y guardado correctamente',
        cliente: clienteGuardado,
        servidor: {
            timestamp: new Date().toISOString(),
            version: '2.0.0',
            endpoint: '/clientes',
            totalClientes: clientes.length
        }
    });
});

// 📦 POST /clientes/multiples - Para múltiples clientes
app.post('/clientes/multiples', (req, res) => {
    console.log('\n📦 POST /clientes/multiples - Recibiendo múltiples clientes...');
    
    const { clientes: nuevosClientes } = req.body;
    const total = req.body.total || nuevosClientes?.length || 0;
    
    console.log(`   📊 Total declarado: ${total}`);
    console.log(`   📦 Array recibido: ${Array.isArray(nuevosClientes) ? nuevosClientes.length : 'No es array'}`);

    if (!Array.isArray(nuevosClientes)) {
        console.log('❌ Error: No se recibió un array de clientes');
        return res.status(400).json({
            error: 'Se esperaba un array de clientes',
            message: 'Formato incorrecto'
        });
    }

    console.log('\n👥 PROCESANDO CLIENTES EN LOTE:');
    const clientesCreados = [];
    let siguienteId = Math.max(...clientes.map(c => c.id)) + 1;

    nuevosClientes.forEach((clienteData, index) => {
        console.log(`\n   👤 Cliente ${index + 1}/${nuevosClientes.length}:`);
        console.log(`      Nombre: ${clienteData.nombre || 'Sin nombre'}`);
        console.log(`      Email: ${clienteData.email || 'Sin email'}`);
        console.log(`      Teléfono: ${clienteData.telefono || 'N/A'}`);
        
        if (clienteData.nombre && clienteData.email) {
            const nuevoCliente = {
                id: siguienteId++,
                nombre: clienteData.nombre,
                email: clienteData.email,
                telefono: clienteData.telefono || '',
                direccion: clienteData.direccion || '',
                fecha_creacion: new Date().toISOString()
            };
            clientes.push(nuevoCliente);
            clientesCreados.push(nuevoCliente);
            console.log(`      ✅ Guardado con ID: ${nuevoCliente.id}`);
        } else {
            console.log(`      ❌ Saltado (datos incompletos)`);
        }
    });

    console.log(`\n💾 Resumen: ${clientesCreados.length} de ${nuevosClientes.length} clientes guardados`);
    console.log(`📊 Total en BD ahora: ${clientes.length} clientes`);

    res.status(201).json({
        success: true,
        message: `${clientesCreados.length} clientes recibidos correctamente`,
        procesados: clientesCreados.length,
        recibidos: nuevosClientes.length,
        clientes: clientesCreados
    });
});

// ❌ Middleware de manejo de errores
app.use((err, req, res, next) => {
    console.log('\n❌ ERROR EN EL SERVIDOR:');
    console.log('━'.repeat(50));
    console.error(`🔥 Error: ${err.message}`);
    console.error(`📍 Stack: ${err.stack}`);
    console.log('━'.repeat(50));
    
    res.status(500).json({
        success: false,
        message: 'Error interno del servidor',
        error: err.message,
        timestamp: new Date().toISOString()
    });
});

// 🔄 Middleware para rutas no encontradas
app.use((req, res) => {
    console.log(`\n❓ RUTA NO ENCONTRADA: ${req.method} ${req.url}`);
    res.status(404).json({
        success: false,
        message: `Ruta no encontrada: ${req.method} ${req.url}`,
        availableEndpoints: [
            'GET /ping',
            'GET /clientes',
            'GET /clientes/buscar',
            'POST /clientes',
            'POST /clientes/multiples'
        ]
    });
});

// 🚀 INICIAR SERVIDOR
const PORT = 3000;
const HOST = '0.0.0.0'; // Para acceso desde la red

app.listen(PORT, HOST, () => {
    console.clear(); // Limpiar consola al iniciar
    
    const fecha = new Date().toLocaleString('es-PY', { timeZone: 'America/Asuncion' });
    
    console.log('\n' + '🚀'.repeat(50));
    console.log('🚀 API NODE.JS INICIADA CORRECTAMENTE! 🚀');
    console.log('🚀'.repeat(50));
    
    console.log('\n📍 INFORMACIÓN DEL SERVIDOR:');
    console.log('┌─────────────────────────────────────────────────────┐');
    console.log(`│ 📅 Fecha inicio: ${fecha.padEnd(30)} │`);
    console.log(`│ 🌐 Host: ${HOST.padEnd(42)} │`);
    console.log(`│ 🔌 Puerto: ${PORT.toString().padEnd(40)} │`);
    console.log(`│ 📊 Clientes precargados: ${clientes.length.toString().padEnd(24)} │`);
    console.log('└─────────────────────────────────────────────────────┘');
    
    console.log('\n🌍 URLs DE ACCESO:');
    console.log(`   📱 Desde Flutter: http://192.168.100.128:${PORT}`);
    console.log(`   💻 Local:         http://localhost:${PORT}`);
    
    console.log('\n🎯 ENDPOINTS DISPONIBLES:');
    console.log('┌──────────────────────────────────────────────────────────┐');
    console.log('│ 🏓 GET  /ping                    - Verificar conexión   │');
    console.log('│ 📋 GET  /clientes                - Obtener todos         │');
    console.log('│ 🔍 GET  /clientes/buscar?q=...   - Buscar clientes       │');
    console.log('│ ➕ POST /clientes                - Crear cliente         │');
    console.log('│ 📦 POST /clientes/multiples      - Crear múltiples       │');
    console.log('└──────────────────────────────────────────────────────────┘');
    
    console.log('\n📡 ESTADO: Esperando peticiones de Flutter...');
    console.log('   (Todos los datos enviados serán mostrados en detalle)');
    console.log('\n' + '─'.repeat(80));
});