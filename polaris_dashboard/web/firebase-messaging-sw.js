importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

// Replace with your Web App config from Firebase Console.
firebase.initializeApp({
  apiKey: 'AIzaSyBxZNGH-5ydNV6meQ8mmXTjVynxC0NbZFU',
  authDomain: 'polaris-2965e.firebaseapp.com',
  projectId: 'polaris-2965e',
  storageBucket: 'polaris-2965e.appspot.com',
  messagingSenderId: '294412034649',
  appId: '1:294412034649:web:2a23b3fe1a3c5621cc0748',
  measurementId: 'G-J0Z6WPBF7D',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload?.notification?.title || 'Polaris Alert';
  const options = {
    body: payload?.notification?.body || 'New alert received.',
    icon: '/icons/Icon-192.png',
  };

  self.registration.showNotification(title, options);
});
