import '../models/task_item.dart';
import '../persistence/storage_interface.dart';

abstract class TaskRepository {
  Future<List<TaskItem>> getAllTasks();
  Future<void> saveTask(TaskItem task);
  Future<void> deleteTask(String id);
  Future<void> toggleTask(String id);
}

class LocalTaskRepository implements TaskRepository {
  static const String _collectionName = 'tasks';
  final StorageInterface _storage;

  LocalTaskRepository({required StorageInterface storage}) : _storage = storage;

  @override
  Future<List<TaskItem>> getAllTasks() async {
    final list = await _storage.getAll(_collectionName);
    final tasks = list.map((json) => TaskItem.fromJson(json)).toList();
    tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  @override
  Future<void> saveTask(TaskItem task) async {
    await _storage.set(_collectionName, task.id, task.toJson());
  }

  @override
  Future<void> deleteTask(String id) async {
    await _storage.delete(_collectionName, id);
  }

  @override
  Future<void> toggleTask(String id) async {
    final raw = await _storage.get(_collectionName, id);
    if (raw != null) {
      final task = TaskItem.fromJson(raw);
      final updated = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
      );
      await _storage.set(_collectionName, id, updated.toJson());
    }
  }
}
