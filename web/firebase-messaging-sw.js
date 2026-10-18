/* Firebase Cloud Messaging service worker for Flutter web. */
importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyD_TfN2Ym6KH98H4WTiThENmArNGAF59Ho',
  authDomain: 'doormart-delivery.firebaseapp.com',
  projectId: 'doormart-delivery',
  storageBucket: 'doormart-delivery.firebasestorage.app',
  messagingSenderId: '39851747839',
  appId: '1:39851747839:web:736948c25db6a1eddadfca',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  const notification = message.notification || {};
  const data = message.data || {};
  const title = data.title || notification.title || 'Doormart notification';
  const body = data.body || notification.body || '';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    data,
  });
});
