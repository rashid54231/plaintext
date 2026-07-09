import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../models/user.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

class CreateTaskScreen extends StatefulWidget {
  final Task? editTask;

  const CreateTaskScreen({super.key, this.editTask});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  Priority _selectedPriority = Priority.medium;
  List<String> _selectedStudentIds = [];
  List<User> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    if (widget.editTask != null) {
      _titleController.text = widget.editTask!.title;
      _descriptionController.text = widget.editTask!.description;
      _dueDate = widget.editTask!.dueDate;
      _selectedPriority = widget.editTask!.priority;
      _selectedStudentIds = List.from(widget.editTask!.assignedUserIds);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final db = DatabaseService.instance;
    final students = await db.getAllStudents();
    setState(() => _students = students);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _showStudentPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Students (${_selectedStudentIds.length} selected)',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedStudentIds.length == _students.length) {
                                  _selectedStudentIds.clear();
                                } else {
                                  _selectedStudentIds = _students.map((s) => s.id!).toList();
                                }
                              });
                              setModalState(() {});
                            },
                            child: Text(
                              _selectedStudentIds.length == _students.length
                                  ? 'Deselect All'
                                  : 'Select All',
                              style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          final isSelected = _selectedStudentIds.contains(student.id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedStudentIds.add(student.id!);
                                } else {
                                  _selectedStudentIds.remove(student.id);
                                }
                              });
                              setModalState(() {});
                            },
                            title: Text(
                              student.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              student.email,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            secondary: CircleAvatar(
                              radius: 20,
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              child: Text(
                                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          text: 'Confirm (${_selectedStudentIds.length} students)',
                          onPressed: () => Navigator.pop(context),
                          icon: Icons.check_rounded,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one student'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final userProvider = context.read<UserProvider>();
    final taskProvider = context.read<TaskProvider>();
    final manager = userProvider.currentUser;

    if (widget.editTask != null) {
      // Update existing task
      final updatedTask = widget.editTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _selectedPriority,
        assignedUserIds: _selectedStudentIds,
      );

      final success = await taskProvider.updateTask(updatedTask);

      // Update assignments
      if (success) {
        await DatabaseService.instance.updateTaskAssignments(
          widget.editTask!.id!,
          _selectedStudentIds,
        );
      }

      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      // Create new task
      final task = Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedDate: DateTime.now(),
        dueDate: _dueDate,
        assignedByUserId: manager!.id!,
        priority: _selectedPriority,
        assignedUserIds: _selectedStudentIds,
      );

      final success = await taskProvider.createTask(task);
      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task assigned to ${_selectedStudentIds.length} student(s)'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editTask != null ? 'Edit Task' : 'Create Task'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _titleController,
                label: 'Task Title',
                hint: 'Enter task title',
                prefixIcon: Icons.title,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Enter task description',
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildStudentSelector(),
              const SizedBox(height: 20),
              Text(
                'Due Date',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.textHint, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        DateFormatter.formatFull(_dueDate),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Priority',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildPrioritySelector(),
              const SizedBox(height: 32),
              CustomButton(
                text: widget.editTask != null ? 'Update Task' : 'Assign Task',
                isLoading: _isLoading,
                onPressed: _handleSave,
                icon: widget.editTask != null ? Icons.save_rounded : Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentSelector() {
    return GestureDetector(
      onTap: _showStudentPicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: _selectedStudentIds.isNotEmpty ? AppColors.primary : AppColors.border,
            width: _selectedStudentIds.isNotEmpty ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people_rounded,
                  color: _selectedStudentIds.isNotEmpty ? AppColors.primary : AppColors.textHint,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Assign To',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_selectedStudentIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedStudentIds.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            if (_selectedStudentIds.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tap to select students',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedStudentIds.map((id) {
                  final student = _students.firstWhere(
                    (s) => s.id == id,
                    orElse: () => User(name: 'Unknown', email: '', password: '', role: Role.student),
                  );
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    label: Text(
                      student.name,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _selectedStudentIds.remove(id));
                    },
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: Priority.values.map((priority) {
        final isSelected = _selectedPriority == priority;
        final color = _getPriorityColor(priority);

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPriority = priority),
            child: Container(
              margin: EdgeInsets.only(right: priority != Priority.high ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    color: isSelected ? color : AppColors.textHint,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priority.name[0].toUpperCase() + priority.name.substring(1),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return AppColors.highPriority;
      case Priority.medium:
        return AppColors.mediumPriority;
      case Priority.low:
        return AppColors.lowPriority;
    }
  }
}
