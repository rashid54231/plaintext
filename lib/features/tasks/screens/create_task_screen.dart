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
  String? _selectedStudentId;
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
      _selectedStudentId = widget.editTask!.assignedToUserId;
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a student to assign'),
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
      final updatedTask = widget.editTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _selectedPriority,
        assignedToUserId: _selectedStudentId!,
      );

      final success = await taskProvider.updateTask(updatedTask);
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
      final task = Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedDate: DateTime.now(),
        dueDate: _dueDate,
        assignedToUserId: _selectedStudentId!,
        assignedByUserId: manager!.id!,
        priority: _selectedPriority,
      );

      final success = await taskProvider.createTask(task);
      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task assigned successfully'),
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
              Text(
                'Assign To',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildStudentDropdown(),
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
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
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

  Widget _buildStudentDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStudentId,
          isExpanded: true,
          hint: Text(
            'Select a student',
            style: GoogleFonts.inter(color: AppColors.textHint),
          ),
          items: _students.map((student) {
            return DropdownMenuItem<String>(
              value: student.id,
              child: Text(
                '${student.name} (${student.email})',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedStudentId = value);
          },
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
              margin: EdgeInsets.only(
                right: priority != Priority.high ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.1) : AppColors.surface,
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
