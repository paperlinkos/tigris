import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import 'cloud_note_store.dart';

class FirestoreCloudNoteStore implements CloudNoteStore {
  final FirebaseFirestore _firestore;
  static const _timeout = Duration(seconds: 20);

  FirestoreCloudNoteStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  CloudNoteRecord _record(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final timestamp = data['syncedAt'];
    final millis = timestamp is Timestamp
        ? timestamp.millisecondsSinceEpoch
        : 0;
    final deleted = data['deleted'] == true;
    return CloudNoteRecord(
      id: doc.id,
      note: deleted ? null : Note.fromJson(data),
      deleted: deleted,
      syncedAtMillis: millis,
    );
  }

  @override
  Future<List<CloudNoteRecord>> fetchChanged(
    String uid,
    DateTime? since,
  ) async {
    Query<Map<String, dynamic>> query = _notes(uid);
    if (since != null) {
      query = query.where(
        'syncedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(since),
      );
    }
    final snapshot = await query
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    return snapshot.docs.map(_record).toList();
  }

  @override
  Future<CloudNoteRecord> upsert(String uid, Note note) async {
    final ref = _notes(uid).doc(note.id);
    await ref
        .set({
          ...note.toJson(),
          'syncedAt': FieldValue.serverTimestamp(),
          'deleted': false,
        }, SetOptions(merge: true))
        .timeout(_timeout);
    return _record(
      await ref.get(const GetOptions(source: Source.server)).timeout(_timeout),
    );
  }

  @override
  Future<CloudNoteRecord> markDeleted(String uid, String id) async {
    final ref = _notes(uid).doc(id);
    // No merge: a deleted note's text must not stay in the cloud.
    await ref
        .set({
          'id': id,
          'deleted': true,
          'syncedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_timeout);
    return _record(
      await ref.get(const GetOptions(source: Source.server)).timeout(_timeout),
    );
  }
}
