import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy thông tin User (Store hoặc Customer) theo ID
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    if (uid.isEmpty) return null;
    try {
      // Tìm trong collection Users
      final doc = await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) return doc.data();
      
      // Fallback nếu ID là email (một số bản ghi cũ dùng email làm ID)
      final query = await _firestore.collection('Users').where('email', isEqualTo: uid).limit(1).get();
      if (query.docs.isNotEmpty) return query.docs.first.data();
      
      return null;
    } catch (e) {
      return null;
    }
  }
}
