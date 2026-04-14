import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MainApp());
}

// colours
var primaryColor = const Color.fromARGB(255, 156, 132, 201);
var darkPrimaryColor = const Color.fromARGB(255, 120, 100, 170);

// functioning
bool darkMode = false;

class AssessmentSubtask {
  AssessmentSubtask({
    required this.title,
    required this.details,
    required this.date,
    required this.time,
    this.isComplete = false,
  });

  String title;
  String details;
  DateTime date;
  TimeOfDay time;
  bool isComplete;
}

class ScheduledAssessment {
  ScheduledAssessment({
    required this.assessment,
    required this.details,
    required this.date,
    required this.time,
    List<AssessmentSubtask>? subtasks,
    this.isComplete = false,
  }) : subtasks = subtasks ?? [];

  String assessment;
  String details;
  DateTime date;
  TimeOfDay time;
  List<AssessmentSubtask> subtasks;
  bool isComplete;
}

class AssessmentDraft {
  AssessmentDraft({
    required this.assessment,
    required this.details,
    required this.date,
    required this.time,
  });

  final String assessment;
  final String details;
  final DateTime date;
  final TimeOfDay time;
}

class SubtaskDraft {
  SubtaskDraft({
    required this.title,
    required this.details,
    required this.date,
    required this.time,
  });

  final String title;
  final String details;
  final DateTime date;
  final TimeOfDay time;
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _selectedPageIndex = 0;
  final List<ScheduledAssessment> _scheduledTasks = [];

  void _scheduleStateUpdate(VoidCallback update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(update);
    });
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Color _pageTextColor() {
    return darkMode ? Colors.white : Colors.black87;
  }

  Future<void> _showAssessmentDialog({ScheduledAssessment? assessment}) async {
    final appContext = _navigatorKey.currentContext;
    if (appContext == null) {
      return;
    }

    final editingAssessment = assessment;
    final isEditing = editingAssessment != null;
    final assessmentController = TextEditingController(
      text: editingAssessment?.assessment ?? '',
    );
    final detailsController = TextEditingController(
      text: editingAssessment?.details ?? '',
    );
    DateTime selectedDate =
        editingAssessment?.date ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime =
        editingAssessment?.time ?? const TimeOfDay(hour: 17, minute: 0);

    final draft = await showDialog<AssessmentDraft>(
      context: appContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Assessment' : 'Schedule Assessment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: assessmentController,
                      decoration: const InputDecoration(
                        labelText: 'Assessment Title',
                        hintText: 'English Report',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        hintText: 'Include submission notes or planning details',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event, color: primaryColor),
                      title: const Text('Due Date'),
                      subtitle: Text(_formatDate(selectedDate)),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: dialogStateContext,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.schedule, color: primaryColor),
                      title: const Text('Time'),
                      subtitle: Text(_formatTime(selectedTime)),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: dialogStateContext,
                          initialTime: selectedTime,
                        );

                        if (pickedTime != null) {
                          setDialogState(() {
                            selectedTime = pickedTime;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () {
                    final assessmentTitle = assessmentController.text.trim();
                    final assessmentDetails = detailsController.text.trim();

                    if (assessmentTitle.isEmpty || assessmentDetails.isEmpty) {
                      ScaffoldMessenger.of(appContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter both an assessment title and details.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      AssessmentDraft(
                        assessment: assessmentTitle,
                        details: assessmentDetails,
                        date: selectedDate,
                        time: selectedTime,
                      ),
                    );
                  },
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Assessment',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    _scheduleStateUpdate(() {
      if (editingAssessment != null) {
        editingAssessment.assessment = draft.assessment;
        editingAssessment.details = draft.details;
        editingAssessment.date = draft.date;
        editingAssessment.time = draft.time;
      } else {
        _scheduledTasks.add(
          ScheduledAssessment(
            assessment: draft.assessment,
            details: draft.details,
            date: draft.date,
            time: draft.time,
          ),
        );
      }
      _scheduledTasks.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _showSubtaskDialog({
    required ScheduledAssessment parentAssessment,
    AssessmentSubtask? subtask,
  }) async {
    final appContext = _navigatorKey.currentContext;
    if (appContext == null) {
      return;
    }

    final editingSubtask = subtask;
    final isEditing = editingSubtask != null;
    final titleController = TextEditingController(
      text: editingSubtask?.title ?? '',
    );
    final detailsController = TextEditingController(
      text: editingSubtask?.details ?? '',
    );
    DateTime selectedDate =
        editingSubtask?.date ?? parentAssessment.date;
    TimeOfDay selectedTime =
        editingSubtask?.time ?? parentAssessment.time;

    final draft = await showDialog<SubtaskDraft>(
      context: appContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Subtask' : 'Add Subtask'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Subtask Title',
                        hintText: 'Draft introduction',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        hintText: 'What needs to be done in this subtask?',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event, color: primaryColor),
                      title: const Text('Due Date'),
                      subtitle: Text(_formatDate(selectedDate)),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: dialogStateContext,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.schedule, color: primaryColor),
                      title: const Text('Time'),
                      subtitle: Text(_formatTime(selectedTime)),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: dialogStateContext,
                          initialTime: selectedTime,
                        );

                        if (pickedTime != null) {
                          setDialogState(() {
                            selectedTime = pickedTime;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () {
                    final subtaskTitle = titleController.text.trim();
                    final subtaskDetails = detailsController.text.trim();

                    if (subtaskTitle.isEmpty || subtaskDetails.isEmpty) {
                      ScaffoldMessenger.of(appContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter both a subtask title and details.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      SubtaskDraft(
                        title: subtaskTitle,
                        details: subtaskDetails,
                        date: selectedDate,
                        time: selectedTime,
                      ),
                    );
                  },
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Subtask',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    _scheduleStateUpdate(() {
      if (editingSubtask != null) {
        editingSubtask.title = draft.title;
        editingSubtask.details = draft.details;
        editingSubtask.date = draft.date;
        editingSubtask.time = draft.time;
      } else {
        parentAssessment.subtasks.add(
          AssessmentSubtask(
            title: draft.title,
            details: draft.details,
            date: draft.date,
            time: draft.time,
          ),
        );
      }

      parentAssessment.subtasks.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Widget _buildAssessmentsPage() {
    final upcomingTasks =
        _scheduledTasks.where((task) => !task.isComplete).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final completedTasks =
        _scheduledTasks.where((task) => task.isComplete).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: darkMode ? darkPrimaryColor : primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assessment Scheduler',
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule assessments and grant them priority levels. Priority levels will determine how often they appear in your plan.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryChip(
                        '${upcomingTasks.length} upcoming',
                        Icons.upcoming,
                      ),
                      _buildSummaryChip(
                        '${completedTasks.length} finished',
                        Icons.check_circle_outline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scheduled Assessments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _pageTextColor(),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () => _showAssessmentDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: darkMode ? 0.22 : 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                
                indicator: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),

                labelColor: Colors.white,
                unselectedLabelColor: _pageTextColor(),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTaskList(
                    tasks: upcomingTasks,
                    emptyTitle: 'No assessments scheduled yet',
                    emptySubtitle:
                        'Get to work, lazy ass. Add an assessment to get started.',
                  ),
                  _buildTaskList(
                    tasks: completedTasks,
                    emptyTitle: 'No completed assessments yet',
                    emptySubtitle:
                        'Tick off an assessment and it will appear here.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList({
    required List<ScheduledAssessment> tasks,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (tasks.isEmpty) {
      return _buildEmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView(
      children: tasks.map(_buildTaskCard).toList(),
    );
  }

  Widget _buildTaskCard(ScheduledAssessment task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: primaryColor.withValues(alpha: darkMode ? 0.35 : 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  activeColor: primaryColor,
                  value: task.isComplete,
                  onChanged: (value) {
                    setState(() {
                      task.isComplete = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.assessment,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: _pageTextColor(),
                          decoration:
                              task.isComplete ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        task.details,
                        style: TextStyle(color: _pageTextColor()),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event, size: 16, color: primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(task.date),
                                style: TextStyle(color: _pageTextColor()),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 16, color: primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(task.time),
                                style: TextStyle(color: _pageTextColor()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: primaryColor),
                  onPressed: () => _showAssessmentDialog(assessment: task),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: primaryColor),
                  onPressed: () {
                    setState(() {
                      _scheduledTasks.remove(task);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtasks',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _pageTextColor(),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showSubtaskDialog(parentAssessment: task),
                  icon: Icon(Icons.add, color: primaryColor, size: 18),
                  label: Text(
                    'Add Subtask',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ],
            ),
            if (task.subtasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No subtasks yet.',
                  style: TextStyle(
                    color: _pageTextColor().withValues(alpha: 0.8),
                  ),
                ),
              )
            else
              ...task.subtasks.map((subtask) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: darkMode ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            activeColor: primaryColor,
                            value: subtask.isComplete,
                            onChanged: (value) {
                              setState(() {
                                subtask.isComplete = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subtask.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _pageTextColor(),
                                    decoration: subtask.isComplete
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtask.details,
                                  style: TextStyle(color: _pageTextColor()),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.event,
                                          size: 16,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(subtask.date),
                                          style: TextStyle(
                                            color: _pageTextColor(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 16,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTime(subtask.time),
                                          style: TextStyle(
                                            color: _pageTextColor(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: primaryColor),
                            onPressed: () => _showSubtaskDialog(
                              parentAssessment: task,
                              subtask: subtask,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: primaryColor),
                            onPressed: () {
                              setState(() {
                                task.subtasks.remove(subtask);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: darkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.task_alt, size: 40, color: primaryColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _pageTextColor(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _pageTextColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: primaryColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _pageTextColor(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _pageTextColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedPageIndex) {
      case 0:
        return _buildAssessmentsPage();
      case 1:
        return _buildPlaceholderPage(
          icon: Icons.calendar_month,
          title: 'Calender',
          subtitle: 'Your assessment work schedule appears here',
        );
      case 2:
        return _buildPlaceholderPage(
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'Bruh there are no settings yet',
        );
      default:
        return _buildAssessmentsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      title: 'Studia',

      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,

          titleTextStyle: GoogleFonts.lato(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        useMaterial3: true,
      ),
      
      darkTheme: ThemeData(
        
        appBarTheme: AppBarTheme(
          backgroundColor: darkPrimaryColor,
          titleTextStyle: GoogleFonts.lato(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        
        scaffoldBackgroundColor: const Color.fromARGB(255, 24, 24, 24),
        
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color.fromARGB(255, 32, 32, 32),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
        ),
        
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

      home: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,

            children: [
              const Text(
                'Studia',

                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 4),
            
            ],
          ),
          
          actions: [
            SwitchTheme(
              data: SwitchThemeData(
                thumbColor: darkMode ? WidgetStateProperty.all(Colors.black) : WidgetStateProperty.all(primaryColor),
                trackColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.5),
                ),
                thumbIcon: darkMode ? const WidgetStatePropertyAll(Icon(Icons.dark_mode)) : const WidgetStatePropertyAll(Icon(Icons.light_mode)),
              ),
              
              child: Switch(
                value: darkMode,

                onChanged: (value) {
                  setState(() {
                    darkMode = value;
                  });
                },
              ),
            ),
          ],
        ),

        body: _buildCurrentPage(),

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedPageIndex,
          onTap: (index) {
            setState(() {
              _selectedPageIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt),
              label: 'Assessments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Calender',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
