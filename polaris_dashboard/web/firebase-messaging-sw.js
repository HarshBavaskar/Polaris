importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

// Replace with your Web App config from Firebase Console.
firebase.initializeApp({
  apiKey: 'AIzaSyBZSEFEj4NWVWXs9yQLDmZVtukJe7IpNCk',
  appId: '1:406400285630:web:627241d55cf7b1df3297ef',
  messagingSenderId: '406400285630',
  projectId: 'polaris-60539',
  authDomain: 'polaris-60539.firebaseapp.com',
  storageBucket: 'polaris-60539.firebasestorage.app',
  measurementId: 'G-LRKEZSZFL3',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // Avoid duplicates: notification payloads are already shown by browser/FCM.
  if (payload && payload.notification) {
    return;
  }

  const title = payload?.notification?.title || 'Polaris Alert';
  const options = {
    body: payload?.data?.message || payload?.notification?.body || 'New alert received.',
    icon: '/icons/Icon-192.png',
    tag: 'polaris-alert',
    renotify: false,
  };

  self.registration.showNotification(title, options);
});
