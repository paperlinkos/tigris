import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/task_item.dart';
import '../../repositories/task_repository.dart';

class TasksView extends StatefulWidget {
  final TaskRepository taskRepository;
  final String searchQuery;

  const TasksView({
    super.key,
    required this.taskRepository,
    this.searchQuery = '',
  });

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final TextEditingController _newController = TextEditingController();
  List<TaskItem> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didUpdateWidget(covariant TasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final tasks = await widget.taskRepository.getAllTasks();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _addTask() async {
    final text = _newController.text.trim();
    if (text.isEmpty) return;

    final newTask = TaskItem(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: text,
      createdAt: DateTime.now(),
    );

    _newController.clear();
    await widget.taskRepository.saveTask(newTask);
    await _loadTasks();
  }

  Future<void> _toggleTask(TaskItem task) async {
    await widget.taskRepository.toggleTask(task.id);
    await _loadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await widget.taskRepository.deleteTask(id);
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: SizedBox.shrink());
    }

    final query = widget.searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _tasks
        : _tasks.where((t) => t.title.toLowerCase().contains(query)).toList();

    final activeTasks = filtered.where((t) => !t.isCompleted).toList();
    final completedTasks = filtered.where((t) => t.isCompleted).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Add Task Input Card
          Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: context.appBorderSubtle, width: 0.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Icon(
                  Icons.add_rounded,
                  color: context.appTextTertiary,
                  size: 22.0,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: TextField(
                    controller: _newController,
                    onSubmitted: (_) => _addTask(),
                    style: AppTypography.body(
                      fontSize: 16.0,
                      color: context.appTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      hintStyle: TextStyle(color: context.appTextTertiary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18.0),
                  color: context.appTextPrimary,
                  onPressed: _addTask,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24.0),

          // Empty State
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 40.0,
                      color: context.appTextTertiary,
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      query.isEmpty ? 'No tasks yet' : 'No matching tasks',
                      style: AppTypography.body(
                        fontSize: 15.0,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Active Tasks List
          if (activeTasks.isNotEmpty) ...[
            Text(
              'TASKS (${activeTasks.length})',
              style: AppTypography.uiLabel(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: context.appTextTertiary,
              ).copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: 10.0),
            for (final task in activeTasks) _buildTaskItem(context, task),
            const SizedBox(height: 24.0),
          ],

          // 3. Completed Tasks List
          if (completedTasks.isNotEmpty) ...[
            Text(
              'COMPLETED (${completedTasks.length})',
              style: AppTypography.uiLabel(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: context.appTextTertiary,
              ).copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: 10.0),
            for (final task in completedTasks) _buildTaskItem(context, task),
          ],

          const SizedBox(height: 80.0),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: task.isCompleted ? context.appBg : context.appSurface,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: context.appBorderSubtle.withAlpha(task.isCompleted ? 100 : 255),
          width: 0.8,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
        leading: GestureDetector(
          onTap: () => _toggleTask(task),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22.0,
            height: 22.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isCompleted ? context.appTextPrimary : Colors.transparent,
              border: Border.all(
                color: task.isCompleted ? context.appTextPrimary : context.appTextTertiary,
                width: 1.8,
              ),
            ),
            child: task.isCompleted
                ? Icon(
                    Icons.check_rounded,
                    size: 14.0,
                    color: context.appBg,
                  )
                : null,
          ),
        ),
        title: Text(
          task.title,
          style: AppTypography.body(
            fontSize: 15.5,
            color: task.isCompleted ? context.appTextTertiary : context.appTextPrimary,
          ).copyWith(
            decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
            decorationColor: context.appTextTertiary,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: 18.0,
            color: context.appTextTertiary,
          ),
          onPressed: () => _deleteTask(task.id),
        ),
      ),
    );
  }
}
