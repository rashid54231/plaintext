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
import '../../../services/notification_service.dart';
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
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _isLoading = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);
  Priority _priority = Priority.medium;
  List<String> _selectedStudentIds = [];
  List<User> _students = [];

  static const List<String> _categories = [
    'Homework', 'Project', 'Quiz', 'Assignment',
    'Research', 'Presentation', 'Report', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    if (widget.editTask != null) {
      final t = widget.editTask!;
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description;
      _categoryCtrl.text = t.category ?? '';
      _dueDate = t.dueDate;
      _dueTime = TimeOfDay.fromDateTime(t.dueDate);
      _priority = t.priority;
      _selectedStudentIds = List.from(t.assignedUserIds);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final students = await DatabaseService.instance.getAllStudents();
    setState(() => _students = students);
  }

  DateTime get _combinedDueDate => DateTime(
    _dueDate.year, _dueDate.month, _dueDate.day,
    _dueTime.hour, _dueTime.minute,
  );

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  void _showStudentPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollCtrl) {
            return StatefulBuilder(
              builder: (context, setModal) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final bg = isDark ? AppColors.surfaceDark : Colors.white;
                return Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Students (${_selectedStudentIds.length} selected)',
                                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (_selectedStudentIds.length == _students.length) {
                                    _selectedStudentIds.clear();
                                  } else {
                                    _selectedStudentIds = _students.map((s) => s.id!).toList();
                                  }
                                });
                                setModal(() {});
                              },
                              child: Text(
                                _selectedStudentIds.length == _students.length ? 'Deselect All' : 'Select All',
                                style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _students.isEmpty
                            ? Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: AppColors.textHint),
                                  const SizedBox(height: 12),
                                  Text('No students registered yet', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                                ],
                              ))
                            : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: _students.length,
                                itemBuilder: (context, index) {
                                  final s = _students[index];
                                  final isSelected = _selectedStudentIds.contains(s.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) _selectedStudentIds.add(s.id!);
                                        else _selectedStudentIds.remove(s.id);
                                      });
                                      setModal(() {});
                                    },
                                    title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                    subtitle: Text(s.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                    secondary: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isSelected ? AppColors.primary : AppColors.divider,
                                      child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : AppColors.textSecondary)),
                                    ),
                                    activeColor: AppColors.primary,
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
                  ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select at least one student'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _isLoading = true);
    final manager = context.read<UserProvider>().currentUser;
    final taskProvider = context.read<TaskProvider>();

    if (widget.editTask != null) {
      final updated = widget.editTask!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        dueDate: _combinedDueDate,
        priority: _priority,
        category: _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : null,
        assignedUserIds: _selectedStudentIds,
      );
      final success = await taskProvider.updateTask(updated);
      if (success) {
        await DatabaseService.instance.updateTaskAssignments(
          widget.editTask!.id!, _selectedStudentIds);
      }
      setState(() => _isLoading = false);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Task updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.of(context).pop();
      }
    } else {
      final task = Task(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        assignedDate: DateTime.now(),
        dueDate: _combinedDueDate,
        assignedByUserId: manager!.id!,
        priority: _priority,
        category: _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : null,
        assignedUserIds: _selectedStudentIds,
      );
      final success = await taskProvider.createTask(task);
      setState(() => _isLoading = false);
      if (success && mounted) {
        // Schedule notifications for each student
        final taskId = taskProvider.assignedTasks.last.id;
        if (taskId != null) {
          await NotificationService.instance.scheduleTaskReminder(
            taskId: taskId,
            taskTitle: task.title,
            dueDate: task.dueDate,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Task assigned to ${_selectedStudentIds.length} student(s)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
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
                controller: _titleCtrl,
                label: 'Task Title *',
                hint: 'Enter a clear task title',
                prefixIcon: Icons.title_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _descCtrl,
                label: 'Description',
                hint: 'Describe what needs to be done...',
                prefixIcon: Icons.description_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildCategoryField(isDark),
              const SizedBox(height: 16),
              _buildStudentSelector(isDark),
              const SizedBox(height: 16),
              _buildDateTimeRow(isDark),
              const SizedBox(height: 16),
              _buildPrioritySelector(isDark),
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

  Widget _buildCategoryField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _categoryCtrl.text == cat;
            return GestureDetector(
              onTap: () => setState(() => _categoryCtrl.text = isSelected ? '' : cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.cardDark : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border, width: 1.5),
                ),
                child: Text(cat,
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStudentSelector(bool isDark) {
    final card = isDark ? AppColors.cardDark : Colors.white;
    return GestureDetector(
      onTap: _showStudentPicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
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
                Icon(Icons.people_rounded,
                  color: _selectedStudentIds.isNotEmpty ? AppColors.primary : AppColors.textHint, size: 20),
                const SizedBox(width: 8),
                Text('Assign To *',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                const Spacer(),
                if (_selectedStudentIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text('${_selectedStudentIds.length}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
              ],
            ),
            if (_selectedStudentIds.isEmpty) ...[
              const SizedBox(height: 8),
              Text('Tap to select students',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint)),
            ] else ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _selectedStudentIds.map((id) {
                  final s = _students.firstWhere(
                    (st) => st.id == id,
                    orElse: () => User(name: 'Unknown', email: '', password: '', role: Role.student),
                  );
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    label: Text(s.name, style: GoogleFonts.inter(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _selectedStudentIds.remove(id)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeRow(bool isDark) {
    final card = isDark ? AppColors.cardDark : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Due Date & Time',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(DateFormatter.formatShort(_dueDate),
                          style: GoogleFonts.inter(fontSize: 13,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(_dueTime.format(context),
                        style: GoogleFonts.inter(fontSize: 13,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrioritySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: Priority.values.map((p) {
            final isSelected = _priority == p;
            final color = p == Priority.high ? AppColors.highPriority
                : p == Priority.medium ? AppColors.mediumPriority
                : AppColors.lowPriority;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = p),
                child: Container(
                  margin: EdgeInsets.only(right: p != Priority.high ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.1) : (isDark ? AppColors.cardDark : Colors.white),
                    border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.flag_rounded, color: isSelected ? color : AppColors.textHint, size: 22),
                      const SizedBox(height: 4),
                      Text(p.name[0].toUpperCase() + p.name.substring(1),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                          color: isSelected ? color : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
