importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCZ76G-kTWS1iOFvfk0-OK2qY5iR1Dyj3A',
  appId: '1:615687440592:web:7f71ac3c67ee1d1d5436d5',
  messagingSenderId: '615687440592',
  projectId: 'mic-backoffice',
  authDomain: 'mic-backoffice.firebaseapp.com',
  storageBucket: 'mic-backoffice.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || data.title || 'SysteMIC';
  const options = {
    body: notification.body || data.body || '',
    data,
  };

  self.registration.showNotification(title, options);
});
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCZ76G-kTWS1iOFvfk0-OK2qY5iR1Dyj3A',
  authDomain: 'mic-backoffice.firebaseapp.com',
  projectId: 'mic-backoffice',
  storageBucket: 'mic-backoffice.firebasestorage.app',
  messagingSenderId: '615687440592',
  appId: '1:615687440592:web:7f71ac3c67ee1d1d5436d5',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || payload.data?.title || 'SysteMIC';
  const options = {
    body: notification.body || payload.data?.body || '',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});
