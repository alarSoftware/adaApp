const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Lista de clientes de ejemplo
let clientes = [
    { id: 1, nombre: 'Juan Pérez', email: 'juan@email.com', telefono: '0981-123456', direccion: 'Asunción, Paraguay' },
    { id: 2, nombre: 'María García', email: 'maria@email.com', telefono: '0984-654321', direccion: 'Luque, Paraguay' },
    { id: 3, nombre: 'Carlos López', email: 'carlos@email.com', telefono: '0985-789123', direccion: 'San Lorenzo, Paraguay' },
    { id: 4, nombre: 'Ronaldo Rebollo', email: 'ronaldo@email.com', telefono: '0986-987654', direccion: 'Fernando de la Mora' },
    { id: 5, nombre: 'Ana Martínez', email: 'ana@email.com', telefono: '0987-112233', direccion: 'San Lorenzo' },
    { id: 6, nombre: 'Pedro Fernández', email: 'pedro@email.com', telefono: '0988-445566', direccion: 'Luque' },
    { id: 7, nombre: 'Lucía Gómez', email: 'lucia@email.com', telefono: '0989-778899', direccion: 'Asunción' },
    { id: 8, nombre: 'Diego Ramírez', email: 'diego@email.com', telefono: '0990-223344', direccion: 'San Lorenzo' },
    { id: 9, nombre: 'Sofía Torres', email: 'sofia@email.com', telefono: '0991-556677', direccion: 'Luque' },
    { id: 10, nombre: 'Miguel Díaz', email: 'miguel@email.com', telefono: '0992-889900', direccion: 'Asunción' },
    { id: 11, nombre: 'Valentina Ríos', email: 'valentina@email.com', telefono: '0993-111222', direccion: 'Capiatá' },
    { id: 12, nombre: 'Javier Medina', email: 'javier@email.com', telefono: '0994-333444', direccion: 'Asunción' },
    { id: 13, nombre: 'Camila Sánchez', email: 'camila@email.com', telefono: '0995-555666', direccion: 'Luque' },
    { id: 14, nombre: 'Andrés Villalba', email: 'andres@email.com', telefono: '0996-777888', direccion: 'San Lorenzo' },
    { id: 15, nombre: 'Laura Duarte', email: 'laura@email.com', telefono: '0997-999000', direccion: 'Fernando de la Mora' },
    { id: 16, nombre: 'Gonzalo Torres', email: 'gonzalo@email.com', telefono: '0998-111333', direccion: 'Capiatá' },
    { id: 17, nombre: 'Paola Giménez', email: 'paola@email.com', telefono: '0999-444555', direccion: 'Lambaré' },
    { id: 18, nombre: 'Martín Benítez', email: 'martin@email.com', telefono: '0971-666777', direccion: 'Asunción' },
    { id: 19, nombre: 'Florencia Caballero', email: 'florencia@email.com', telefono: '0972-888999', direccion: 'San Lorenzo' },
    { id: 20, nombre: 'Hernán Vera', email: 'hernan@email.com', telefono: '0973-000111', direccion: 'Luque' },
    { id: 21, nombre: 'Daniela López', email: 'daniela@email.com', telefono: '0974-222333', direccion: 'Asunción' },
    { id: 22, nombre: 'Sebastián Acosta', email: 'sebastian@email.com', telefono: '0975-444555', direccion: 'Capiatá' },
    { id: 23, nombre: 'Natalia Rojas', email: 'natalia@email.com', telefono: '0976-666777', direccion: 'San Lorenzo' },
    { id: 24, nombre: 'Pablo Martínez', email: 'pablo@email.com', telefono: '0977-888999', direccion: 'Fernando de la Mora' },
    { id: 25, nombre: 'Marisol Cáceres', email: 'marisol@email.com', telefono: '0978-000111', direccion: 'Luque' },
    { id: 26, nombre: 'Rodrigo Ayala', email: 'rodrigo@email.com', telefono: '0979-222333', direccion: 'Lambaré' },
    { id: 27, nombre: 'Isabel Franco', email: 'isabel@email.com', telefono: '0961-444555', direccion: 'Asunción' },
    { id: 28, nombre: 'Federico Ortiz', email: 'federico@email.com', telefono: '0962-666777', direccion: 'San Lorenzo' },
    { id: 29, nombre: 'Gabriela Núñez', email: 'gabriela@email.com', telefono: '0963-888999', direccion: 'Luque' },
    { id: 30, nombre: 'Tomás González', email: 'tomas@email.com', telefono: '0964-000111', direccion: 'Capiatá' }
];

// 🔹 Endpoint adicional para verificar conexión
app.get('/ping', (req, res) => {
    res.json({
        mensaje: 'Servidor funcionando correctamente',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Endpoint para listar clientes con límite y paginación
app.get('/clientes', (req, res) => {
    const page = parseInt(req.query.page) || 1;  // Página actual, default 1
    const limit = parseInt(req.query.limit) || 5; // Cantidad de resultados por página, default 5

    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;

    const resultados = clientes.slice(startIndex, endIndex);

    res.json({
        total: clientes.length,
        page,
        limit,
        clientes: resultados,
    });
});

// Endpoint para buscar clientes por nombre o email
app.get('/clientes/buscar', (req, res) => {
    const q = req.query.q?.toLowerCase() || '';
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;

    const encontrados = clientes.filter(c =>
        c.nombre.toLowerCase().includes(q) || c.email.toLowerCase().includes(q)
    );

    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const resultados = encontrados.slice(startIndex, endIndex);

    res.json({
        total: encontrados.length,
        page,
        limit,
        clientes: resultados
    });
});

// Endpoint para crear un cliente (envía JSON)
app.post('/clientes', (req, res) => {
    const { nombre, email, telefono, direccion } = req.body;

    // Validación básica
    if (!nombre || !email) {
        return res.status(400).json({
            error: 'Nombre y email son requeridos',
            mensaje: 'Faltan campos obligatorios'
        });
    }

    const nuevoCliente = {
        id: Math.max(...clientes.map(c => c.id)) + 1, // ID más seguro
        nombre,
        email,
        telefono: telefono || '',
        direccion: direccion || '',
        fecha_creacion: new Date().toISOString()
    };

    clientes.push(nuevoCliente);
    console.log(`✅ Cliente creado: ${nuevoCliente.nombre}`);
    res.status(201).json(nuevoCliente);
});

// 🔹 Endpoint para múltiples clientes
app.post('/clientes/multiples', (req, res) => {
    const { clientes: nuevosClientes } = req.body;

    if (!Array.isArray(nuevosClientes)) {
        return res.status(400).json({
            error: 'Se esperaba un array de clientes',
            mensaje: 'Formato incorrecto'
        });
    }

    const clientesCreados = [];
    let siguienteId = Math.max(...clientes.map(c => c.id)) + 1;

    for (const clienteData of nuevosClientes) {
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
        }
    }

    console.log(`✅ ${clientesCreados.length} clientes creados en lote`);
    res.status(201).json(clientesCreados);
});

// Servidor - 🔥 ESTA ES LA LÍNEA CLAVE QUE CAMBIÓ
const PORT = 3000;
const HOST = '0.0.0.0'; // 🔥 Esto permite conexiones desde cualquier IP

app.listen(PORT, HOST, () => {
    console.log(`🚀 API corriendo en:`);
    console.log(`   Local:    http://localhost:${PORT}`);
    console.log(`   Red:      http:// 192.168.1.185:${PORT}`);
    console.log(`   Endpoints disponibles:`);
    console.log(`   📋 GET  /clientes`);
    console.log(`   🔍 GET  /clientes/buscar?q=texto`);
    console.log(`   ➕ POST /clientes`);
    console.log(`   📦 POST /clientes/multiples`);
    console.log(`   🏓 GET  /ping`);
});