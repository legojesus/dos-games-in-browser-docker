const http = require('http');
const { exec } = require('child_process');

const PORT = 8080;

// Simple container restart API
const server = http.createServer((req, res) => {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // Parse URL - expecting /restart/:container
    const match = req.url.match(/^\/restart\/([a-z0-9_-]+)$/i);

    if (req.method === 'POST' && match) {
        const container = match[1];

        // Whitelist of allowed containers to restart
        const allowedContainers = ['homm3'];

        if (!allowedContainers.includes(container)) {
            res.writeHead(403, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Container not allowed' }));
            return;
        }

        // Use docker compose restart for the specific service
        const projectName = 'dos-games-website';
        exec(`docker restart ${projectName}-${container}-1`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Restart error: ${error.message}`);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Failed to restart container', details: error.message }));
                return;
            }

            console.log(`Container ${container} restarted successfully`);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: true, message: `Container ${container} restarted` }));
        });
    } else if (req.url === '/health' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok' }));
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Not found' }));
    }
});

server.listen(PORT, () => {
    console.log(`Manager service running on port ${PORT}`);
});
