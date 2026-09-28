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
  final _maxMarksCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();
  bool _isLoading = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);
  Priority _priority = Priority.medium;
  List<String> _selectedStudentIds = [];
  List<User> _students = [];
  List<SubTask> _subtasks = [];

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
      _maxMarksCtrl.text = t.maxMarks?.toString() ?? '';
      _dueDate = t.dueDate;
      _dueTime = TimeOfDay.fromDateTime(t.dueDate);
      _priority = t.priority;
      _selectedStudentIds = List.from(t.assignedUserIds);
      _subtasks = List.from(t.subtasks);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _maxMarksCtrl.dispose();
    _subtaskCtrl.dispose();
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


  void _showStudentPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String classFilter = 'All';

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollCtrl) {
            return StatefulBuilder(
              builder: (context, setModal) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final bg = isDark ? AppColors.surfaceDark : Colors.white;

                final classCodes = _students
                    .map((s) => s.classCode)
                    .where((c) => c != null && c.trim().isNotEmpty)
                    .map((c) => c!.trim())
                    .toSet()
                    .toList();

                final displayedStudents = classFilter == 'All'
                    ? _students
                    : _students.where((s) => s.classCode?.trim() == classFilter).toList();

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
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Select Students (${_selectedStudentIds.length} selected)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
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
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Class / Batch Filters
                      if (classCodes.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  label: Text('All (${_students.length})'),
                                  selected: classFilter == 'All',
                                  selectedColor: AppColors.primary,
                                  checkmarkColor: Colors.white,
                                  labelStyle: TextStyle(color: classFilter == 'All' ? Colors.white : null),
                                  onSelected: (val) => setModal(() => classFilter = 'All'),
                                ),
                                ...classCodes.map((c) {
                                  final isSelected = classFilter == c;
                                  final count = _students.where((s) => s.classCode?.trim() == c).length;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: FilterChip(
                                      label: Text('$c ($count)'),
                                      selected: isSelected,
                                      selectedColor: AppColors.primary,
                                      checkmarkColor: Colors.white,
                                      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                                      onSelected: (val) => setModal(() => classFilter = c),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        if (classFilter != 'All') ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  ),
                                  icon: const Icon(Icons.group_add_rounded, size: 16, color: AppColors.primary),
                                  label: Text(
                                    'Select All in Class "$classFilter"',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  onPressed: () {
                                    final classStudentIds = _students
                                        .where((s) => s.classCode?.trim() == classFilter)
                                        .map((s) => s.id!)
                                        .toList();
                                    setState(() {
                                      for (final id in classStudentIds) {
                                        if (!_selectedStudentIds.contains(id)) {
                                          _selectedStudentIds.add(id);
                                        }
                                      }
                                    });
                                    setModal(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      const Divider(height: 12),
                      Expanded(
                        child: displayedStudents.isEmpty
                            ? Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: AppColors.textHint),
                                  const SizedBox(height: 12),
                                  Text('No students in this class', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                                ],
                              ))
                            : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: displayedStudents.length,
                                itemBuilder: (context, index) {
                                  final s = displayedStudents[index];
                                  final isSelected = _selectedStudentIds.contains(s.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedStudentIds.add(s.id!);
                                        } else {
                                          _selectedStudentIds.remove(s.id);
                                        }
                                      });
                                      setModal(() {});
                                    },
                                    title: Text(s.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500)),
                                    subtitle: Row(
                                      children: [
                                        Text(s.email, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                                        if (s.classCode != null && s.classCode!.trim().isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              s.classCode!,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    secondary: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isSelected ? AppColors.primary : AppColors.divider,
                                      child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold,
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
        maxMarks: int.tryParse(_maxMarksCtrl.text.trim()),
        assignedUserIds: _selectedStudentIds,
        subtasks: _subtasks,
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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(taskProvider.error ?? 'Failed to update task'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
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
        maxMarks: int.tryParse(_maxMarksCtrl.text.trim()),
        assignedUserIds: _selectedStudentIds,
        subtasks: _subtasks,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Task assigned to ${_selectedStudentIds.length} student(s)'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(taskProvider.error ?? 'Failed to assign task'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.background;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.editTask != null ? 'Edit Task' : 'New Task',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              CustomTextField(
                controller: _titleCtrl,
                label: 'Title',
                hint: 'Develop UX Prototypes',
                prefixIcon: Icons.title_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // Description Field
              CustomTextField(
                controller: _descCtrl,
                label: 'Description',
                hint: 'Define user flows for onboarding and your rounds and the assets.',
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Due Date Field (Slide 2)
              _buildDueDateField(isDark),
              const SizedBox(height: 16),

              // Priority Selector (Slide 2: High, Medium, Low pills)
              _buildPrioritySelector(isDark),
              const SizedBox(height: 18),

              // Assignee Selector (Slide 2: Avatars row + Add button)
              _buildStudentSelector(isDark),
              const SizedBox(height: 16),

              // Category Field
              _buildCategoryField(isDark),
              const SizedBox(height: 16),

              // Optional Max Marks
              CustomTextField(
                controller: _maxMarksCtrl,
                label: 'Max Marks',
                hint: 'Optional: e.g. 100',
                prefixIcon: Icons.star_border_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 18),

              // Subtasks & Steps Section
              _buildSubtasksSection(isDark),
              const SizedBox(height: 28),

              // Submit Button
              CustomButton(
                text: widget.editTask != null ? 'Update Task' : 'Assign Task',
                isLoading: _isLoading,
                onPressed: _handleSave,
                icon: widget.editTask != null ? Icons.save_rounded : Icons.send_rounded,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtasksSection(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final card = isDark ? AppColors.cardDark : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Assignment Checklist / Subtasks (Optional)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const Spacer(),
            if (_subtasks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_subtasks.length} steps',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subtaskCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Step 1: Read Chapter 3',
                  prefixIcon: const Icon(Icons.add_task_rounded, size: 18, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _addSubtask(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addSubtask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
        if (_subtasks.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...List.generate(_subtasks.length, (index) {
            final st = _subtasks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      st.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                    onPressed: () {
                      setState(() => _subtasks.removeAt(index));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  void _addSubtask() {
    final text = _subtaskCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(SubTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: text,
      ));
      _subtaskCtrl.clear();
    });
  }

  Widget _buildCategoryField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600,
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w600,
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

  // Slide 2: Assignee Selector (Horizontal Avatars row + "+ Add" circular button)
  Widget _buildStudentSelector(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assignee Selector',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            if (_selectedStudentIds.isNotEmpty)
              Text(
                '${_selectedStudentIds.length} selected',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Display students as round avatars
              ..._students.map((student) {
                final isSelected = _selectedStudentIds.contains(student.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedStudentIds.remove(student.id);
                      } else {
                        _selectedStudentIds.add(student.id!);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 52,
                          child: Text(
                            student.name.split(' ').first,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primary : textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // "+ Add" circular button
              GestureDetector(
                onTap: _showStudentPicker,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.add, size: 22, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+ Add',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Slide 2: Due Date Field (clean single box with date and calendar icon)
  Widget _buildDueDateField(bool isDark) {
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: card,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormatter.formatShort(_dueDate),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textHint,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Slide 2: Priority Selector (High, Medium, Low 3 horizontal pills)
  Widget _buildPrioritySelector(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority Selector',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _priorityPill(Priority.high, 'High', const Color(0xFFEF4444), isDark),
            const SizedBox(width: 10),
            _priorityPill(Priority.medium, 'Medium', const Color(0xFFF59E0B), isDark),
            const SizedBox(width: 10),
            _priorityPill(Priority.low, 'Low', const Color(0xFF10B981), isDark),
          ],
        ),
      ],
    );
  }

  Widget _priorityPill(Priority p, String label, Color color, bool isDark) {
    final isSelected = _priority == p;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
