const { io } = require('socket.io-client');

// Colle ici un accessToken obtenu via POST /auth/login
const TOKEN = 'eyJhbGci...';

const socket = io('http://localhost:3000/realtime', {
  auth: { token: TOKEN },
  transports: ['websocket'],
});

socket.on('connected', (data) => console.log('Authentifie :', data));
socket.on('unauthorized', (data) => console.log('Refuse :', data));
socket.on('notification:new', (n) => console.log('Notification :', n));
socket.on('attendance:updated', (a) => console.log('Presence :', a));
socket.on('announcement:new', (a) => console.log('Annonce :', a));
socket.on('disconnect', (reason) => console.log('Deconnecte :', reason));