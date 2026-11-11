import 'package:firebase_core/firebase_core.dart';

/// Configuração do app web no projeto Firebase `society-fut`. Não é segredo:
/// quem protege os dados são as regras do Firestore (firestore.rules).
const firebaseWebOptions = FirebaseOptions(
  apiKey: 'AIzaSyBOhoEgRdWRT31zX3yMwCA7P8WLnHtvg4o',
  appId: '1:871039131571:web:33b432bb082b85c44d35c6',
  messagingSenderId: '871039131571',
  projectId: 'society-fut',
  authDomain: 'society-fut.firebaseapp.com',
  storageBucket: 'society-fut.firebasestorage.app',
);

bool get firebaseConfigured => firebaseWebOptions.apiKey.isNotEmpty;
