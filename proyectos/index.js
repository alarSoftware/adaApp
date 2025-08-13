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
    // Puedes generar más si querés muchos más clientes
];

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
    const encontrados = clientes.filter(c =>
        c.nombre.toLowerCase().includes(q) || c.email.toLowerCase().includes(q)
    );
    res.json(encontrados);
});

// Endpoint para crear un cliente (envía JSON)
app.post('/clientes', (req, res) => {
    const { nombre, email, telefono, direccion } = req.body;
    const nuevoCliente = {
        id: clientes.length + 1,
        nombre,
        email,
        telefono,
        direccion
    };
    clientes.push(nuevoCliente);
    res.status(201).json(nuevoCliente);
});

// Servidor
const PORT = 3000;
app.listen(PORT, () => console.log(`API en http://localhost:${PORT}`));
