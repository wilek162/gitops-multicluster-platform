const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const messages = [];

app.use(express.json());
app.use(express.static('public'));

app.get('/api/messages', (req, res) => {
    res.json(messages);
});

app.post('/api/messages', (req, res) => {
    const message = {
        id: Date.now(),
        text: req.body.text,
        timestamp: new Date().toISOString()
    };
    messages.push(message);
    res.json(message);
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(port, () => {
    console.log(`Guestbook listening on port ${port}`);
});
