import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';
import 'note_repository.dart';

class FirestoreNoteRepository implements NoteRepository {
  final FirebaseFirestore _firestore;
  final String Function()? userIdGetter;
  final String fallbackCollectionName;

  FirestoreNoteRepository({
    FirebaseFirestore? firestore,
    this.userIdGetter,
    this.fallbackCollectionName = 'notes',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  String get _currentUserId {
    final id = userIdGetter?.call();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        return uid;
      }
    } catch (_) {}
    return 'guest_user';
  }

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = _currentUserId;
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  @override
  Future<Note?> getNote(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return Note.fromJson(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Note>> getAllNotes() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs
          .map((doc) => Note.fromJson(doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Note>> getRootNotes() async {
    try {
      final all = await getAllNotes();
      return all.where((n) => n.isRoot).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Note>> getChildNotes(String parentId) async {
    try {
      final parent = await getNote(parentId);
      if (parent == null) return [];
      final childNotes = <Note>[];
      for (final childId in parent.childrenIds) {
        final child = await getNote(childId);
        if (child != null) {
          childNotes.add(child);
        }
      }
      return childNotes;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 10}) async {
    try {
      final all = await getAllNotes();
      all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return all.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<Note>> watchAllNotes() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Note.fromJson(doc.data())).toList();
    }).handleError((_) => <Note>[]);
  }

  @override
  Stream<List<Note>> watchRecentNotes({int limit = 10}) {
    return watchAllNotes().map((all) {
      final sorted = List<Note>.from(all)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sorted.take(limit).toList();
    });
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final all = await getAllNotes();
      return all.where((note) {
        final title = note.title.toLowerCase();
        final content = note.content.toLowerCase();
        final subtitle = (note.subtitle ?? '').toLowerCase();
        return title.contains(q) || content.contains(q) || subtitle.contains(q);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Note>> getAncestorPath(String noteId) async {
    final ancestors = <Note>[];
    String? currentId = noteId;

    while (currentId != null) {
      final note = await getNote(currentId);
      if (note == null) break;
      ancestors.insert(0, note);
      currentId = note.parentId;
    }

    return ancestors;
  }

  @override
  Future<void> saveNote(Note note) async {
    final json = note.toJson();
    await _collection.doc(note.id).set(json, SetOptions(merge: true));

    // Update parent's childrenIds if parentId is present
    if (note.parentId != null) {
      final parent = await getNote(note.parentId!);
      if (parent != null && !parent.childrenIds.contains(note.id)) {
        final updatedParent = parent.copyWith(
          childrenIds: [...parent.childrenIds, note.id],
          updatedAt: DateTime.now(),
        );
        await _collection.doc(parent.id).set(updatedParent.toJson(), SetOptions(merge: true));
      }
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    final target = await getNote(id);
    if (target == null) return;

    // Delete all child notes recursively
    for (final childId in target.childrenIds) {
      await deleteNote(childId);
    }

    // Remove from parent's childrenIds list
    if (target.parentId != null) {
      final parent = await getNote(target.parentId!);
      if (parent != null) {
        final updatedParent = parent.copyWith(
          childrenIds: parent.childrenIds.where((cId) => cId != id).toList(),
          updatedAt: DateTime.now(),
        );
        await _collection.doc(parent.id).set(updatedParent.toJson(), SetOptions(merge: true));
      }
    }

    await _collection.doc(id).delete();
  }
}
