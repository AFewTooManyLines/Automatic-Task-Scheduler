import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
    this.priorityRank = 3,
    this.colorTagValue = 0xFF1E88E5,
    List<AssessmentSubtask>? subtasks,
    this.isComplete = false,
  }) : subtasks = subtasks ?? [];

  String assessment;
  String details;
  DateTime date;
  TimeOfDay time;
  int priorityRank;
  int colorTagValue;
  List<AssessmentSubtask> subtasks;
  bool isComplete;
}

class AssessmentDraft {
  AssessmentDraft({
    required this.assessment,
    required this.details,
    required this.date,
    required this.time,
    required this.priorityRank,
    required this.colorTagValue,
  });

  final String assessment;
  final String details;
  final DateTime date;
  final TimeOfDay time;
  final int priorityRank;
  final int colorTagValue;
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

class BlockedStudyPeriod {
  BlockedStudyPeriod({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  int weekday;
  TimeOfDay startTime;
  TimeOfDay endTime;
}

class BlockedStudyDatePeriod {
  BlockedStudyDatePeriod({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
}

enum CalendarEntryType { due, study }

class StudyCalendarEntry {
  StudyCalendarEntry({
    required this.type,
    required this.assessment,
    required this.date,
    this.startTime,
    this.endTime,
  });

  CalendarEntryType type;
  ScheduledAssessment assessment;
  DateTime date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
}

class _MinuteRange {
  const _MinuteRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _AssessmentTagOption {
  const _AssessmentTagOption({required this.colorValue, required this.label});

  final int colorValue;
  final String label;
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  int _selectedPageIndex = 0;
  final List<ScheduledAssessment> _scheduledTasks = [];
  final Set<int> _availableWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };
  final List<BlockedStudyPeriod> _blockedStudyPeriods = [];
  final List<BlockedStudyDatePeriod> _blockedStudyDatePeriods = [];
  TimeOfDay _schoolReturnTime = const TimeOfDay(hour: 15, minute: 30);
  TimeOfDay _studyEndTime = const TimeOfDay(hour: 21, minute: 0);
  late DateTime _calendarMonth;
  late DateTime _selectedCalendarDate;
  StreamSubscription<User?>? _authStateSubscription;
  bool _isApplyingCloudData = false;
  bool _cloudSyncInProgress = false;
  bool _pendingCloudSync = false;
  bool _hasShownSyncError = false;
  bool _isAuthBusy = false;

  Null get tasks => null;

  static const List<String> _weekdayShortNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<int> _weekdayOrderSundayFirst = [
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
  ];
  static const List<String> _calendarHeaderNames = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
  static const List<_AssessmentTagOption> _assessmentTagOptions = [
    _AssessmentTagOption(colorValue: 0xFF1E88E5, label: 'Blue'),
    _AssessmentTagOption(colorValue: 0xFF43A047, label: 'Green'),
    _AssessmentTagOption(colorValue: 0xFFE53935, label: 'Red'),
    _AssessmentTagOption(colorValue: 0xFFF4511E, label: 'Orange'),
    _AssessmentTagOption(colorValue: 0xFF8E24AA, label: 'Purple'),
    _AssessmentTagOption(colorValue: 0xFF00897B, label: 'Teal'),
    _AssessmentTagOption(colorValue: 0xFF3949AB, label: 'Indigo'),
    _AssessmentTagOption(colorValue: 0xFF6D4C41, label: 'Brown'),
    _AssessmentTagOption(colorValue: 0xFF5E35B1, label: 'Violet'),
    _AssessmentTagOption(colorValue: 0xFF039BE5, label: 'Sky'),
    _AssessmentTagOption(colorValue: 0xFF7CB342, label: 'Lime'),
    _AssessmentTagOption(colorValue: 0xFFFFB300, label: 'Amber'),
    _AssessmentTagOption(colorValue: 0xFFD81B60, label: 'Pink'),
    _AssessmentTagOption(colorValue: 0xFF546E7A, label: 'Slate'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
    _selectedCalendarDate = DateTime(now.year, now.month, now.day);
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user == null) {
        return;
      }
      _loadPlannerFromCloud(user.uid);
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _scheduleStateUpdate(VoidCallback update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(update);
      _recordPlannerChange();
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

  String _formatMonthYear(DateTime date) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  String _weekdayLabel(int weekday) {
    return _weekdayShortNames[weekday - 1];
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  TimeOfDay _minutesToTime(int totalMinutes) {
    final wrapped = totalMinutes % (24 * 60);
    final positive = wrapped < 0 ? wrapped + (24 * 60) : wrapped;
    final hour = positive ~/ 60;
    final minute = positive % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Color _tagColorFromValue(int colorValue) {
    return Color(colorValue);
  }

  int _normalizeTagColorValue(int value) {
    final isValid = _assessmentTagOptions.any(
      (option) => option.colorValue == value,
    );
    return isValid ? value : _assessmentTagOptions.first.colorValue;
  }

  String _tagLabelFromValue(int value) {
    for (final option in _assessmentTagOptions) {
      if (option.colorValue == value) {
        return option.label;
      }
    }
    return _assessmentTagOptions.first.label;
  }

  Future<TimeOfDay?> _pickTimeWithAppContext({
    required TimeOfDay initialTime,
    BuildContext? fallbackContext,
  }) async {
    final pickerContext = _navigatorKey.currentContext ?? fallbackContext;
    if (pickerContext == null) {
      return null;
    }
    return showTimePicker(context: pickerContext, initialTime: initialTime);
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime _assessmentDueDateTime(ScheduledAssessment assessment) {
    return _combineDateAndTime(assessment.date, assessment.time);
  }

  int _compareByRankThenDue(ScheduledAssessment a, ScheduledAssessment b) {
    final rankCompare = a.priorityRank.compareTo(b.priorityRank);
    if (rankCompare != 0) {
      return rankCompare;
    }

    final dueCompare = _assessmentDueDateTime(
      a,
    ).compareTo(_assessmentDueDateTime(b));
    if (dueCompare != 0) {
      return dueCompare;
    }

    return a.assessment.toLowerCase().compareTo(b.assessment.toLowerCase());
  }

  int _compareBlockedDatePeriods(
    BlockedStudyDatePeriod a,
    BlockedStudyDatePeriod b,
  ) {
    final dateCompare = _dateOnly(a.date).compareTo(_dateOnly(b.date));
    if (dateCompare != 0) {
      return dateCompare;
    }

    return _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime));
  }

  DocumentReference<Map<String, dynamic>> _plannerDocument(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('planner')
        .doc('state');
  }

  String _dateToStorage(DateTime date) {
    final safeDate = _dateOnly(date);
    final month = safeDate.month.toString().padLeft(2, '0');
    final day = safeDate.day.toString().padLeft(2, '0');
    return '${safeDate.year}-$month-$day';
  }

  DateTime _dateFromStorage(dynamic rawValue, DateTime fallback) {
    if (rawValue is Timestamp) {
      final date = rawValue.toDate();
      return _dateOnly(date);
    }
    if (rawValue is String) {
      final parsed = DateTime.tryParse(rawValue);
      if (parsed != null) {
        return _dateOnly(parsed);
      }
    }
    return _dateOnly(fallback);
  }

  TimeOfDay _timeFromStorage(dynamic rawValue, {required TimeOfDay fallback}) {
    if (rawValue is Map) {
      final hourRaw = rawValue['hour'];
      final minuteRaw = rawValue['minute'];
      if (hourRaw is int && minuteRaw is int) {
        final safeHour = hourRaw.clamp(0, 23);
        final safeMinute = minuteRaw.clamp(0, 59);
        return TimeOfDay(hour: safeHour, minute: safeMinute);
      }
    }
    return fallback;
  }

  Map<String, int> _timeToStorage(TimeOfDay time) {
    return {'hour': time.hour, 'minute': time.minute};
  }

  Map<String, dynamic> _serializePlannerState() {
    final sortedDays = _availableWeekdays.toList()..sort();

    return {
      'availableWeekdays': sortedDays,
      'schoolReturnTime': _timeToStorage(_schoolReturnTime),
      'studyEndTime': _timeToStorage(_studyEndTime),
      'blockedStudyPeriods': _blockedStudyPeriods.map((item) {
        return {
          'weekday': item.weekday,
          'startTime': _timeToStorage(item.startTime),
          'endTime': _timeToStorage(item.endTime),
        };
      }).toList(),
      'blockedStudyDatePeriods': _blockedStudyDatePeriods.map((item) {
        return {
          'date': _dateToStorage(item.date),
          'startTime': _timeToStorage(item.startTime),
          'endTime': _timeToStorage(item.endTime),
        };
      }).toList(),
      'scheduledTasks': _scheduledTasks.map((task) {
        return {
          'assessment': task.assessment,
          'details': task.details,
          'date': _dateToStorage(task.date),
          'time': _timeToStorage(task.time),
          'priorityRank': task.priorityRank,
          'colorTagValue': task.colorTagValue,
          'isComplete': task.isComplete,
          'subtasks': task.subtasks.map((subtask) {
            return {
              'title': subtask.title,
              'details': subtask.details,
              'date': _dateToStorage(subtask.date),
              'time': _timeToStorage(subtask.time),
              'isComplete': subtask.isComplete,
            };
          }).toList(),
        };
      }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ScheduledAssessment? _parseScheduledAssessment(dynamic rawValue) {
    if (rawValue is! Map) {
      return null;
    }

    final title = rawValue['assessment'];
    final details = rawValue['details'];
    if (title is! String || details is! String) {
      return null;
    }

    final dueDate = _dateFromStorage(rawValue['date'], DateTime.now());
    final dueTime = _timeFromStorage(
      rawValue['time'],
      fallback: const TimeOfDay(hour: 17, minute: 0),
    );
    final rawRank = rawValue['priorityRank'];
    var priorityRank = rawRank is int ? rawRank.clamp(1, 10) : 3;
    if (rawRank is! int) {
      final legacyPriority = rawValue['priority'];
      if (legacyPriority is String) {
        switch (legacyPriority.toLowerCase()) {
          case 'high':
            priorityRank = 1;
            break;
          case 'medium':
            priorityRank = 3;
            break;
          case 'low':
            priorityRank = 6;
            break;
          default:
            break;
        }
      }
    }
    final isComplete = rawValue['isComplete'] == true;
    final rawColorTag = rawValue['colorTagValue'];
    final colorTagValue = rawColorTag is int
        ? _normalizeTagColorValue(rawColorTag)
        : _assessmentTagOptions.first.colorValue;

    final subtasks = <AssessmentSubtask>[];
    final rawSubtasks = rawValue['subtasks'];
    if (rawSubtasks is List) {
      for (final rawSubtask in rawSubtasks) {
        if (rawSubtask is! Map) {
          continue;
        }

        final subtaskTitle = rawSubtask['title'];
        final subtaskDetails = rawSubtask['details'];
        if (subtaskTitle is! String || subtaskDetails is! String) {
          continue;
        }

        subtasks.add(
          AssessmentSubtask(
            title: subtaskTitle,
            details: subtaskDetails,
            date: _dateFromStorage(rawSubtask['date'], dueDate),
            time: _timeFromStorage(rawSubtask['time'], fallback: dueTime),
            isComplete: rawSubtask['isComplete'] == true,
          ),
        );
      }
    }

    subtasks.sort((a, b) => a.date.compareTo(b.date));

    return ScheduledAssessment(
      assessment: title,
      details: details,
      date: dueDate,
      time: dueTime,
      priorityRank: priorityRank,
      colorTagValue: colorTagValue,
      subtasks: subtasks,
      isComplete: isComplete,
    );
  }

  Future<void> _loadPlannerFromCloud(String uid) async {
    try {
      final snapshot = await _plannerDocument(uid).get();
      if (!mounted) {
        return;
      }

      final data = snapshot.data();
      if (data == null) {
        await _queueCloudSync();
        return;
      }

      final loadedTasks = <ScheduledAssessment>[];
      final rawTasks = data['scheduledTasks'];
      if (rawTasks is List) {
        for (final rawTask in rawTasks) {
          final parsedTask = _parseScheduledAssessment(rawTask);
          if (parsedTask != null) {
            loadedTasks.add(parsedTask);
          }
        }
      }
      loadedTasks.sort(_compareByRankThenDue);

      final loadedDays = <int>{};
      final rawDays = data['availableWeekdays'];
      if (rawDays is List) {
        for (final rawDay in rawDays) {
          if (rawDay is int &&
              rawDay >= DateTime.monday &&
              rawDay <= DateTime.sunday) {
            loadedDays.add(rawDay);
          }
        }
      }
      if (loadedDays.isEmpty) {
        loadedDays.addAll({
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        });
      }

      final loadedBlockedPeriods = <BlockedStudyPeriod>[];
      final rawBlockedPeriods = data['blockedStudyPeriods'];
      if (rawBlockedPeriods is List) {
        for (final rawItem in rawBlockedPeriods) {
          if (rawItem is! Map) {
            continue;
          }

          final rawWeekday = rawItem['weekday'];
          if (rawWeekday is! int || rawWeekday < 1 || rawWeekday > 7) {
            continue;
          }

          final startTime = _timeFromStorage(
            rawItem['startTime'],
            fallback: const TimeOfDay(hour: 18, minute: 0),
          );
          final endTime = _timeFromStorage(
            rawItem['endTime'],
            fallback: const TimeOfDay(hour: 19, minute: 0),
          );
          if (_timeToMinutes(endTime) <= _timeToMinutes(startTime)) {
            continue;
          }

          loadedBlockedPeriods.add(
            BlockedStudyPeriod(
              weekday: rawWeekday,
              startTime: startTime,
              endTime: endTime,
            ),
          );
        }
      }
      loadedBlockedPeriods.sort((a, b) {
        final weekdayCompare = a.weekday.compareTo(b.weekday);
        if (weekdayCompare != 0) {
          return weekdayCompare;
        }
        return _timeToMinutes(
          a.startTime,
        ).compareTo(_timeToMinutes(b.startTime));
      });

      final loadedBlockedDatePeriods = <BlockedStudyDatePeriod>[];
      final rawBlockedDatePeriods = data['blockedStudyDatePeriods'];
      if (rawBlockedDatePeriods is List) {
        for (final rawItem in rawBlockedDatePeriods) {
          if (rawItem is! Map) {
            continue;
          }

          final rawDate = rawItem['date'];
          if (rawDate == null) {
            continue;
          }

          final startTime = _timeFromStorage(
            rawItem['startTime'],
            fallback: const TimeOfDay(hour: 18, minute: 0),
          );
          final endTime = _timeFromStorage(
            rawItem['endTime'],
            fallback: const TimeOfDay(hour: 19, minute: 0),
          );
          if (_timeToMinutes(endTime) <= _timeToMinutes(startTime)) {
            continue;
          }

          loadedBlockedDatePeriods.add(
            BlockedStudyDatePeriod(
              date: _dateFromStorage(rawDate, DateTime.now()),
              startTime: startTime,
              endTime: endTime,
            ),
          );
        }
      }
      loadedBlockedDatePeriods.sort(_compareBlockedDatePeriods);

      final loadedReturnTime = _timeFromStorage(
        data['schoolReturnTime'],
        fallback: const TimeOfDay(hour: 15, minute: 30),
      );
      final loadedEndTime = _timeFromStorage(
        data['studyEndTime'],
        fallback: const TimeOfDay(hour: 21, minute: 0),
      );

      _isApplyingCloudData = true;
      try {
        setState(() {
          _scheduledTasks
            ..clear()
            ..addAll(loadedTasks);
          _availableWeekdays
            ..clear()
            ..addAll(loadedDays);
          _blockedStudyPeriods
            ..clear()
            ..addAll(loadedBlockedPeriods);
          _blockedStudyDatePeriods
            ..clear()
            ..addAll(loadedBlockedDatePeriods);
          _schoolReturnTime = loadedReturnTime;
          _studyEndTime = loadedEndTime;
        });
      } finally {
        _isApplyingCloudData = false;
      }
      _hasShownSyncError = false;
    } catch (error) {
      if (!_hasShownSyncError && mounted) {
        _showSnackBar('Could not load your planner from cloud.');
        _hasShownSyncError = true;
      }
    }
  }

  Future<void> _queueCloudSync() async {
    if (_isApplyingCloudData) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    if (_cloudSyncInProgress) {
      _pendingCloudSync = true;
      return;
    }

    _cloudSyncInProgress = true;
    try {
      await _plannerDocument(
        user.uid,
      ).set(_serializePlannerState(), SetOptions(merge: true));
      _hasShownSyncError = false;
    } catch (error) {
      if (!_hasShownSyncError && mounted) {
        _showSnackBar('Unable to sync planner changes right now.');
        _hasShownSyncError = true;
      }
    } finally {
      _cloudSyncInProgress = false;
      if (_pendingCloudSync) {
        _pendingCloudSync = false;
        await _queueCloudSync();
      }
    }
  }

  void _recordPlannerChange() {
    _queueCloudSync();
  }

  List<_MinuteRange> _subtractBlockedRange(
    List<_MinuteRange> ranges,
    _MinuteRange blocked,
  ) {
    final result = <_MinuteRange>[];

    for (final range in ranges) {
      if (blocked.end <= range.start || blocked.start >= range.end) {
        result.add(range);
        continue;
      }

      if (blocked.start > range.start) {
        result.add(
          _MinuteRange(
            start: range.start,
            end: math.min(blocked.start, range.end),
          ),
        );
      }

      if (blocked.end < range.end) {
        result.add(
          _MinuteRange(
            start: math.max(blocked.end, range.start),
            end: range.end,
          ),
        );
      }
    }

    return result.where((range) => range.end > range.start).toList();
  }

  List<_MinuteRange> _availableRangesForDate(DateTime date) {
    var startMinutes = _timeToMinutes(_schoolReturnTime);
    final endMinutes = _timeToMinutes(_studyEndTime);
    final now = DateTime.now();
    if (_isSameDate(date, now)) {
      startMinutes = math.max(
        startMinutes,
        _timeToMinutes(TimeOfDay(hour: now.hour, minute: now.minute)),
      );
    }

    if (endMinutes <= startMinutes) {
      return [];
    }

    var ranges = <_MinuteRange>[
      _MinuteRange(start: startMinutes, end: endMinutes),
    ];

    for (final blocked in _blockedStudyPeriods.where(
      (item) => item.weekday == date.weekday,
    )) {
      final blockedStart = _timeToMinutes(blocked.startTime);
      final blockedEnd = _timeToMinutes(blocked.endTime);
      if (blockedEnd <= blockedStart) {
        continue;
      }

      ranges = _subtractBlockedRange(
        ranges,
        _MinuteRange(start: blockedStart, end: blockedEnd),
      );
    }

    for (final blocked in _blockedStudyDatePeriods.where(
      (item) => _isSameDate(item.date, date),
    )) {
      final blockedStart = _timeToMinutes(blocked.startTime);
      final blockedEnd = _timeToMinutes(blocked.endTime);
      if (blockedEnd <= blockedStart) {
        continue;
      }

      ranges = _subtractBlockedRange(
        ranges,
        _MinuteRange(start: blockedStart, end: blockedEnd),
      );
    }

    return ranges;
  }

  int _targetSessionCount(
    ScheduledAssessment assessment,
    DateTime planStartDateTime,
  ) {
    final dueDateTime = _assessmentDueDateTime(assessment);
    final hoursUntilDue = math.max(
      0,
      dueDateTime.difference(planStartDateTime).inHours,
    );
    final daysUntilDue = hoursUntilDue ~/ 24;
    final normalizedRank = math.max(1, assessment.priorityRank);
    final base = math.max(4, 16 - (normalizedRank * 2));
    final urgencyBoost = math.max(0, (30 - daysUntilDue) ~/ 3);
    return math.max(2, base + urgencyBoost);
  }

  double _assessmentSelectionScore({
    required ScheduledAssessment assessment,
    required DateTime slotStartDateTime,
    required DateTime planStartDateTime,
    required int allocatedSessions,
  }) {
    final dueDateTime = _assessmentDueDateTime(assessment);
    final minutesLeft = math.max(
      1,
      dueDateTime.difference(slotStartDateTime).inMinutes,
    );
    final urgencyScore = 180.0 / minutesLeft;
    final normalizedRank = math.max(1, assessment.priorityRank);
    final rankScore = 18.0 / normalizedRank;
    final targetSessions = _targetSessionCount(assessment, planStartDateTime);
    final deficit = targetSessions - allocatedSessions;

    return rankScore + urgencyScore + (deficit * 3.5);
  }

  Map<DateTime, List<StudyCalendarEntry>> _buildCalendarEntriesByDay() {
    final today = _dateOnly(DateTime.now());
    final planStartDateTime = DateTime.now();
    final activeAssessments =
        _scheduledTasks.where((task) => !task.isComplete).toList()
          ..sort(_compareByRankThenDue);
    final entriesByDay = <DateTime, List<StudyCalendarEntry>>{};

    for (final assessment in activeAssessments) {
      final dueDate = _dateOnly(assessment.date);
      entriesByDay.putIfAbsent(dueDate, () => []);
      entriesByDay[dueDate]!.add(
        StudyCalendarEntry(
          type: CalendarEntryType.due,
          assessment: assessment,
          date: dueDate,
          startTime: assessment.time,
        ),
      );
    }

    if (activeAssessments.isEmpty) {
      return entriesByDay;
    }

    final latestDueDate = activeAssessments
        .map((task) => _dateOnly(task.date))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final sessionCountByAssessment = <ScheduledAssessment, int>{
      for (final assessment in activeAssessments) assessment: 0,
    };

    for (
      var date = today;
      !date.isAfter(latestDueDate);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      if (!_availableWeekdays.contains(date.weekday)) {
        continue;
      }

      final ranges = _availableRangesForDate(date);
      if (ranges.isEmpty) {
        continue;
      }

      for (final range in ranges) {
        var cursor = range.start;
        while (cursor + 45 <= range.end) {
          final slotStartDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            cursor ~/ 60,
            cursor % 60,
          );
          final candidates = activeAssessments.where((assessment) {
            final dueDateTime = _assessmentDueDateTime(assessment);
            return dueDateTime.isAfter(slotStartDateTime);
          }).toList();

          if (candidates.isEmpty) {
            break;
          }

          candidates.sort((a, b) {
            final scoreA = _assessmentSelectionScore(
              assessment: a,
              slotStartDateTime: slotStartDateTime,
              planStartDateTime: planStartDateTime,
              allocatedSessions: sessionCountByAssessment[a] ?? 0,
            );
            final scoreB = _assessmentSelectionScore(
              assessment: b,
              slotStartDateTime: slotStartDateTime,
              planStartDateTime: planStartDateTime,
              allocatedSessions: sessionCountByAssessment[b] ?? 0,
            );

            return scoreB.compareTo(scoreA);
          });

          ScheduledAssessment? selectedAssessment;
          var selectedDuration = 0;

          for (final candidate in candidates) {
            var maxDuration = math.min(60, range.end - cursor);
            if (_isSameDate(date, candidate.date)) {
              final dueMinute = _timeToMinutes(candidate.time);
              maxDuration = math.min(maxDuration, dueMinute - cursor);
            }

            if (maxDuration >= 45) {
              selectedAssessment = candidate;
              selectedDuration = maxDuration;
              break;
            }
          }

          if (selectedAssessment == null || selectedDuration < 45) {
            break;
          }

          final startTime = _minutesToTime(cursor);
          final endTime = _minutesToTime(cursor + selectedDuration);

          entriesByDay.putIfAbsent(date, () => []);
          entriesByDay[date]!.add(
            StudyCalendarEntry(
              type: CalendarEntryType.study,
              assessment: selectedAssessment,
              date: date,
              startTime: startTime,
              endTime: endTime,
            ),
          );
          sessionCountByAssessment[selectedAssessment] =
              (sessionCountByAssessment[selectedAssessment] ?? 0) + 1;

          cursor += selectedDuration;
        }
      }
    }

    for (final entryList in entriesByDay.values) {
      entryList.sort((a, b) {
        if (a.type != b.type) {
          return a.type == CalendarEntryType.due ? -1 : 1;
        }

        final aMinutes = a.startTime == null ? 0 : _timeToMinutes(a.startTime!);
        final bMinutes = b.startTime == null ? 0 : _timeToMinutes(b.startTime!);
        return aMinutes.compareTo(bMinutes);
      });
    }

    return entriesByDay;
  }

  Color _priorityColor(int rank) {
    if (rank <= 2) {
      return const Color(0xFFC62828);
    }
    if (rank <= 4) {
      return const Color(0xFFEF6C00);
    }
    return const Color(0xFF2E7D32);
  }

  Color _pageTextColor() {
    return darkMode ? Colors.white : Colors.black87;
  }

  void _showSnackBar(String message) {
    final appContext = _navigatorKey.currentContext;
    if (appContext == null) {
      return;
    }

    ScaffoldMessenger.of(
      appContext,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isAuthBusy) {
      return;
    }

    setState(() {
      _isAuthBusy = true;
    });

    try {
      await action();
      _showSnackBar(successMessage);
    } on FirebaseAuthException catch (error) {
      _showSnackBar(error.message ?? 'Authentication failed.');
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthBusy = false;
      });
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Enter both your email and password.');
      return;
    }

    await _runAuthAction(() async {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    }, successMessage: 'Signed in successfully.');
  }

  Future<void> _createAccount() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Enter both your email and password.');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters.');
      return;
    }

    await _runAuthAction(() async {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }, successMessage: 'Account created successfully.');
  }

  Future<void> _signOut() async {
    await _runAuthAction(() async {
      if (!kIsWeb) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
          case TargetPlatform.iOS:
            break;
          case TargetPlatform.windows:
          case TargetPlatform.macOS:
          case TargetPlatform.linux:
            break;
          default:
            break;
        }
      }

      await _auth.signOut();
    }, successMessage: 'Signed out.');
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

    int selectedPriorityRank = math.max(
      1,
      editingAssessment?.priorityRank ?? 3,
    );

    int selectedColorTagValue = _normalizeTagColorValue(
      editingAssessment?.colorTagValue ??
          _assessmentTagOptions.first.colorValue,
    );

    final draft = await showDialog<AssessmentDraft>(
      context: appContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Assessment' : 'Schedule Assessment',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: assessmentController,
                      decoration: const InputDecoration(
                        labelText: 'Assessment Title',
                        hintText: 'Engineering Report',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        hintText:
                            'Include submission format, word count, and any other important info',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedPriorityRank,
                      decoration: const InputDecoration(
                        labelText: 'Priority Rank',
                      ),
                      items: List.generate(10, (index) => index + 1).map((
                        rank,
                      ) {
                        return DropdownMenuItem(
                          value: rank,
                          child: Text('$rank'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedPriorityRank = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Color Tag',
                        style: Theme.of(
                          dialogStateContext,
                        ).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _assessmentTagOptions.map((tagOption) {
                        final isSelected =
                            selectedColorTagValue == tagOption.colorValue;
                        final tagColor = _tagColorFromValue(
                          tagOption.colorValue,
                        );
                        return ChoiceChip(
                          selected: isSelected,
                          selectedColor: tagColor.withValues(
                            alpha: darkMode ? 0.34 : 0.20,
                          ),
                          label: Text(tagOption.label),
                          avatar: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: tagColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          onSelected: (_) {
                            setDialogState(() {
                              selectedColorTagValue = tagOption.colorValue;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
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
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
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
                        priorityRank: selectedPriorityRank,
                        colorTagValue: selectedColorTagValue,
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
        editingAssessment.priorityRank = draft.priorityRank;
        editingAssessment.colorTagValue = draft.colorTagValue;
      } else {
        _scheduledTasks.add(
          ScheduledAssessment(
            assessment: draft.assessment,
            details: draft.details,
            date: draft.date,
            time: draft.time,
            priorityRank: draft.priorityRank,
            colorTagValue: draft.colorTagValue,
          ),
        );
      }
      _scheduledTasks.sort(_compareByRankThenDue);
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
    DateTime selectedDate = editingSubtask?.date ?? parentAssessment.date;
    TimeOfDay selectedTime = editingSubtask?.time ?? parentAssessment.time;

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
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
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

  Future<void> _showBlockedStudyPeriodDialog({
    BlockedStudyPeriod? period,
  }) async {
    final appContext = _navigatorKey.currentContext;
    if (appContext == null) {
      return;
    }

    final editingPeriod = period;
    int selectedWeekday = editingPeriod?.weekday ?? DateTime.monday;
    TimeOfDay selectedStart =
        editingPeriod?.startTime ?? const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay selectedEnd =
        editingPeriod?.endTime ?? const TimeOfDay(hour: 19, minute: 0);

    final result = await showDialog<BlockedStudyPeriod>(
      context: appContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) {
            return AlertDialog(
              title: Text(
                editingPeriod == null
                    ? 'Add Blocked Time'
                    : 'Edit Blocked Time',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedWeekday,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: _weekdayOrderSundayFirst.map((day) {
                        return DropdownMenuItem(
                          value: day,
                          child: Text(_weekdayLabel(day)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedWeekday = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.login, color: primaryColor),
                      title: const Text('Start'),
                      subtitle: Text(_formatTime(selectedStart)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogStateContext,
                          initialTime: selectedStart,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedStart = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout, color: primaryColor),
                      title: const Text('End'),
                      subtitle: Text(_formatTime(selectedEnd)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogStateContext,
                          initialTime: selectedEnd,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedEnd = picked;
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
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    if (_timeToMinutes(selectedEnd) <=
                        _timeToMinutes(selectedStart)) {
                      ScaffoldMessenger.of(appContext).showSnackBar(
                        const SnackBar(
                          content: Text('End time must be after start time.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      BlockedStudyPeriod(
                        weekday: selectedWeekday,
                        startTime: selectedStart,
                        endTime: selectedEnd,
                      ),
                    );
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (editingPeriod == null) {
        _blockedStudyPeriods.add(result);
      } else {
        editingPeriod.weekday = result.weekday;
        editingPeriod.startTime = result.startTime;
        editingPeriod.endTime = result.endTime;
      }
      _blockedStudyPeriods.sort((a, b) {
        final dayCompare = a.weekday.compareTo(b.weekday);
        if (dayCompare != 0) {
          return dayCompare;
        }

        return _timeToMinutes(
          a.startTime,
        ).compareTo(_timeToMinutes(b.startTime));
      });
    });
    _recordPlannerChange();
  }

  Future<void> _showBlockedStudyDatePeriodDialog({
    BlockedStudyDatePeriod? period,
    DateTime? initialDate,
  }) async {
    final appContext = _navigatorKey.currentContext;
    if (appContext == null) {
      return;
    }

    final editingPeriod = period;
    DateTime selectedDate = _dateOnly(
      editingPeriod?.date ?? initialDate ?? _selectedCalendarDate,
    );
    TimeOfDay selectedStart =
        editingPeriod?.startTime ?? const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay selectedEnd =
        editingPeriod?.endTime ?? const TimeOfDay(hour: 19, minute: 0);

    final result = await showDialog<BlockedStudyDatePeriod>(
      context: appContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) {
            return AlertDialog(
              title: Text(
                editingPeriod == null
                    ? 'Add Date Blocked Time'
                    : 'Edit Date Blocked Time',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today, color: primaryColor),
                      title: const Text('Date'),
                      subtitle: Text(_formatDate(selectedDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogStateContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000, 1, 1),
                          lastDate: DateTime(2100, 12, 31),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = _dateOnly(picked);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.login, color: primaryColor),
                      title: const Text('Start'),
                      subtitle: Text(_formatTime(selectedStart)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogStateContext,
                          initialTime: selectedStart,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedStart = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout, color: primaryColor),
                      title: const Text('End'),
                      subtitle: Text(_formatTime(selectedEnd)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogStateContext,
                          initialTime: selectedEnd,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedEnd = picked;
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
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    if (_timeToMinutes(selectedEnd) <=
                        _timeToMinutes(selectedStart)) {
                      ScaffoldMessenger.of(appContext).showSnackBar(
                        const SnackBar(
                          content: Text('End time must be after start time.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      BlockedStudyDatePeriod(
                        date: selectedDate,
                        startTime: selectedStart,
                        endTime: selectedEnd,
                      ),
                    );
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (editingPeriod == null) {
        _blockedStudyDatePeriods.add(result);
      } else {
        editingPeriod.date = result.date;
        editingPeriod.startTime = result.startTime;
        editingPeriod.endTime = result.endTime;
      }
      _blockedStudyDatePeriods.sort(_compareBlockedDatePeriods);
    });
    _recordPlannerChange();
  }

  Widget _buildAssessmentsPage() {
    final upcomingTasks =
        _scheduledTasks.where((task) => !task.isComplete).toList()
          ..sort(_compareByRankThenDue);
    final completedTasks =
        _scheduledTasks.where((task) => task.isComplete).toList()
          ..sort(_compareByRankThenDue);

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
                    style: GoogleFonts.lato(color: Colors.white, fontSize: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule assessments and assign priority ranks to generate a study plan based on proximity, importance and available time.',
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
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
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
                        'Get to work lazy ass. Add an assessment to get started.',
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

  Widget _buildPriorityChip(int rank) {
    final chipColor = _priorityColor(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: darkMode ? 0.32 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Rank $rank',
        style: TextStyle(
          color: darkMode ? Colors.white : chipColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTagChip(int colorValue) {
    final tagColor = _tagColorFromValue(colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: darkMode ? 0.32 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _tagLabelFromValue(colorValue),
            style: TextStyle(
              color: darkMode ? Colors.white : tagColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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
      return _buildEmptyState(title: emptyTitle, subtitle: emptySubtitle);
    }

    return ListView(children: tasks.map(_buildTaskCard).toList());
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
                    _recordPlannerChange();
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
                          decoration: task.isComplete
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        task.details,
                        style: TextStyle(color: _pageTextColor()),
                      ),
                      const SizedBox(height: 10),
                      _buildTagChip(task.colorTagValue),
                      const SizedBox(height: 8),
                      _buildPriorityChip(task.priorityRank),
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
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: primaryColor,
                              ),
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
                    _recordPlannerChange();
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
                    color: primaryColor.withValues(
                      alpha: darkMode ? 0.18 : 0.08,
                    ),
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
                              _recordPlannerChange();
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
                            icon: Icon(
                              Icons.edit_outlined,
                              color: primaryColor,
                            ),
                            onPressed: () => _showSubtaskDialog(
                              parentAssessment: task,
                              subtask: subtask,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                task.subtasks.remove(subtask);
                              });
                              _recordPlannerChange();
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

  Widget _buildEmptyState({required String title, required String subtitle}) {
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _pageTextColor()),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarPage() {
    final entriesByDay = _buildCalendarEntriesByDay();
    final selectedDate = _dateOnly(_selectedCalendarDate);
    final selectedEntries = List<StudyCalendarEntry>.from(
      entriesByDay[selectedDate] ?? <StudyCalendarEntry>[],
    );
    final studySessionCount = entriesByDay.values
        .expand((items) => items)
        .where((item) => item.type == CalendarEntryType.study)
        .length;
    final dueCount = entriesByDay.values
        .expand((items) => items)
        .where((item) => item.type == CalendarEntryType.due)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'Study Calendar',
                  style: GoogleFonts.lato(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your study plan is shown here. Configure availability settings to generate a suitable schedule for yourself',
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
                      '$dueCount due deadlines',
                      Icons.warning_amber_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1040) {
                final calendarWidth = math.min(
                  560.0,
                  constraints.maxWidth * 0.50,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: calendarWidth * 1.3,
                      child: Column(
                        children: [
                          _buildMonthCalendar(entriesByDay),
                          const SizedBox(height: 16),
                          _buildDateBlockedTimeCard(selectedDate: selectedDate),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _buildAvailabilitySettingsCard(),
                          const SizedBox(height: 16),
                          _buildSelectedDayAgenda(
                            selectedDate: selectedDate,
                            entries: selectedEntries,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _buildMonthCalendar(entriesByDay),
                  const SizedBox(height: 16),
                  _buildDateBlockedTimeCard(selectedDate: selectedDate),
                  const SizedBox(height: 16),
                  _buildAvailabilitySettingsCard(),
                  const SizedBox(height: 16),
                  _buildSelectedDayAgenda(
                    selectedDate: selectedDate,
                    entries: selectedEntries,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySettingsCard() {
    return Card(
      elevation: 20,
      shadowColor: Colors.black,
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
            Text(
              'Availability Rules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _pageTextColor(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The planner schedules sessions from your return time until your study cutoff.',
              style: TextStyle(color: _pageTextColor().withValues(alpha: 0.82)),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.home_filled, color: primaryColor),
              title: const Text('Back From School'),
              subtitle: Text(_formatTime(_schoolReturnTime)),
              onTap: () async {
                final picked = await _pickTimeWithAppContext(
                  initialTime: _schoolReturnTime,
                  fallbackContext: context,
                );

                if (picked == null) {
                  return;
                }

                if (_timeToMinutes(picked) >= _timeToMinutes(_studyEndTime)) {
                  _showSnackBar(
                    'Return time must be earlier than study end time.',
                  );
                  return;
                }

                setState(() {
                  _schoolReturnTime = picked;
                });
                _recordPlannerChange();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.nights_stay_outlined, color: primaryColor),
              title: const Text('Study Until'),
              subtitle: Text(_formatTime(_studyEndTime)),
              onTap: () async {
                final picked = await _pickTimeWithAppContext(
                  initialTime: _studyEndTime,
                  fallbackContext: context,
                );

                if (picked == null) {
                  return;
                }

                if (_timeToMinutes(picked) <=
                    _timeToMinutes(_schoolReturnTime)) {
                  _showSnackBar(
                    'Study end time must be later than return time.',
                  );
                  return;
                }

                setState(() {
                  _studyEndTime = picked;
                });
                _recordPlannerChange();
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Available Days',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _pageTextColor(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekdayOrderSundayFirst.map((weekday) {
                final isSelected = _availableWeekdays.contains(weekday);
                return FilterChip(
                  selectedColor: primaryColor.withValues(alpha: 0.22),
                  selected: isSelected,
                  checkmarkColor: primaryColor,
                  label: Text(_weekdayLabel(weekday)),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _availableWeekdays.add(weekday);
                        return;
                      }

                      if (_availableWeekdays.length == 1) {
                        _showSnackBar('Keep at least one study day available.');
                        return;
                      }
                      _availableWeekdays.remove(weekday);
                    });
                    _recordPlannerChange();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recurring Blocked Windows',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _pageTextColor(),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showBlockedStudyPeriodDialog(),
                  icon: Icon(Icons.add, color: primaryColor, size: 18),
                  label: Text('Add', style: TextStyle(color: primaryColor)),
                ),
              ],
            ),
            if (_blockedStudyPeriods.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No recurring blocked windows. Your full available time is used.',
                  style: TextStyle(
                    color: _pageTextColor().withValues(alpha: 0.8),
                  ),
                ),
              )
            else
              ..._blockedStudyPeriods.map((period) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(
                      alpha: darkMode ? 0.18 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_weekdayLabel(period.weekday)} | ${_formatTime(period.startTime)} - ${_formatTime(period.endTime)}',
                          style: TextStyle(color: _pageTextColor()),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showBlockedStudyPeriodDialog(period: period),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _blockedStudyPeriods.remove(period);
                          });
                          _recordPlannerChange();
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          color: primaryColor,
                          size: 20,
                        ),
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

  Widget _buildDateBlockedTimeCard({required DateTime selectedDate}) {
    final selectedDayPeriods =
        _blockedStudyDatePeriods
            .where((period) => _isSameDate(period.date, selectedDate))
            .toList()
          ..sort(
            (a, b) => _timeToMinutes(
              a.startTime,
            ).compareTo(_timeToMinutes(b.startTime)),
          );

    return Card(
      elevation: 20,
      shadowColor: Colors.black,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Blocked Time for ${_formatDate(selectedDate)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _pageTextColor(),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showBlockedStudyDatePeriodDialog(
                    initialDate: selectedDate,
                  ),
                  icon: Icon(Icons.add, color: primaryColor, size: 18),
                  label: Text('Add', style: TextStyle(color: primaryColor)),
                ),
              ],
            ),
            Text(
              'These blocked windows only apply to this specific date.',
              style: TextStyle(color: _pageTextColor().withValues(alpha: 0.82)),
            ),
            if (selectedDayPeriods.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No blocked windows for this date.',
                  style: TextStyle(
                    color: _pageTextColor().withValues(alpha: 0.8),
                  ),
                ),
              )
            else
              ...selectedDayPeriods.map((period) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(
                      alpha: darkMode ? 0.18 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_formatTime(period.startTime)} - ${_formatTime(period.endTime)}',
                          style: TextStyle(color: _pageTextColor()),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showBlockedStudyDatePeriodDialog(period: period),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _blockedStudyDatePeriods.remove(period);
                          });
                          _recordPlannerChange();
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          color: primaryColor,
                          size: 20,
                        ),
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

  Widget _buildMonthCalendar(
    Map<DateTime, List<StudyCalendarEntry>> entriesByDay,
  ) {
    final firstOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final firstDayOffset = firstOfMonth.weekday % 7;
    final firstVisibleDate = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1 - firstDayOffset,
    );

    return Card(
      elevation: 20,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: primaryColor.withValues(alpha: darkMode ? 0.35 : 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.chevron_left, color: primaryColor),
                  onPressed: () {
                    setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month - 1,
                      );
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    _formatMonthYear(_calendarMonth),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: _pageTextColor(),
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.chevron_right, color: primaryColor),
                  onPressed: () {
                    setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
            Row(
              children: _calendarHeaderNames.map((dayLabel) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      dayLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _pageTextColor().withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.18,
              ),
              itemBuilder: (context, index) {
                final date = DateTime(
                  firstVisibleDate.year,
                  firstVisibleDate.month,
                  firstVisibleDate.day + index,
                );
                final dayKey = _dateOnly(date);
                final entries = entriesByDay[dayKey] ?? <StudyCalendarEntry>[];
                final dueCount = entries
                    .where((item) => item.type == CalendarEntryType.due)
                    .length;
                final studyCount = entries
                    .where((item) => item.type == CalendarEntryType.study)
                    .length;
                final tagColors = <int>{
                  for (final item in entries) item.assessment.colorTagValue,
                }.toList();
                final isSelected = _isSameDate(dayKey, _selectedCalendarDate);
                final isCurrentMonth = date.month == _calendarMonth.month;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _selectedCalendarDate = dayKey;
                        _calendarMonth = DateTime(dayKey.year, dayKey.month);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(
                                alpha: darkMode ? 0.24 : 0.14,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : primaryColor.withValues(
                                  alpha: darkMode ? 0.18 : 0.10,
                                ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isCurrentMonth
                                  ? _pageTextColor()
                                  : _pageTextColor().withValues(alpha: 0.4),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (dueCount > 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'DUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          if (studyCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$studyCount study',
                                style: TextStyle(
                                  color: darkMode ? Colors.white : primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          if (tagColors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: tagColors.take(3).map((colorValue) {
                                  return Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 3),
                                    decoration: BoxDecoration(
                                      color: _tagColorFromValue(colorValue),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayAgenda({
    required DateTime selectedDate,
    required List<StudyCalendarEntry> entries,
  }) {
    DateTime entryStart(StudyCalendarEntry entry) {
      final startTime = entry.startTime ?? entry.assessment.time;
      return _combineDateAndTime(entry.date, startTime);
    }

    DateTime entryEnd(StudyCalendarEntry entry) {
      if (entry.type == CalendarEntryType.study && entry.endTime != null) {
        return _combineDateAndTime(entry.date, entry.endTime!);
      }
      return entryStart(entry).add(const Duration(minutes: 30));
    }

    final sortedEntries = List<StudyCalendarEntry>.from(entries)
      ..sort((a, b) => entryStart(a).compareTo(entryStart(b)));

    return Card(
      elevation: 20,
      shadowColor: Colors.black,
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
            Text(
              'Plan for ${_formatDate(selectedDate)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _pageTextColor(),
              ),
            ),
            const SizedBox(width: double.infinity, height: 10),
            if (sortedEntries.isEmpty)
              Text(
                'No study blocks or due assessments on this date.',
                style: TextStyle(
                  color: _pageTextColor().withValues(alpha: 0.82),
                ),
              )
            else
              ...sortedEntries.map((entry) {
                final start = entryStart(entry);
                final end = entryEnd(entry);
                final startLabel = _formatTime(
                  TimeOfDay(hour: start.hour, minute: start.minute),
                );
                final endLabel = _formatTime(
                  TimeOfDay(hour: end.hour, minute: end.minute),
                );
                final tagColor = _tagColorFromValue(
                  entry.assessment.colorTagValue,
                );
                final tagLabel = _tagLabelFromValue(
                  entry.assessment.colorTagValue,
                );
                final isDue = entry.type == CalendarEntryType.due;
                final outlineColor = isDue
                    ? Colors.red
                    : tagColor.withValues(alpha: 0.7);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            startLabel,
                            style: TextStyle(
                              color: _pageTextColor().withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: isDue
                                ? Colors.red.withValues(
                                    alpha: darkMode ? 0.24 : 0.12,
                                  )
                                : tagColor.withValues(
                                    alpha: darkMode ? 0.26 : 0.14,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: outlineColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 5, color: tagColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    10,
                                    10,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.assessment.assessment,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: _pageTextColor(),
                                              ),
                                            ),
                                          ),
                                          if (isDue)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade700,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'DUE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$startLabel - $endLabel',
                                        style: TextStyle(
                                          color: _pageTextColor().withValues(
                                            alpha: 0.86,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isDue
                                            ? 'Submission deadline'
                                            : 'Study session',
                                        style: TextStyle(
                                          color: _pageTextColor().withValues(
                                            alpha: 0.82,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildPlaceholderPage({
    String title = 'Coming Soon',
    String subtitle = 'This feature is still in development. Stay tuned!',
    IconData icon = Icons.construction_outlined,
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _pageTextColor()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPage() {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final textColor = _pageTextColor();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Settings',
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user == null
                          ? 'Sign in or sign up to enable cloud-saving'
                          : 'You are signed in and your account is ready for cloud-saving.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: primaryColor.withValues(
                      alpha: darkMode ? 0.35 : 0.18,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: user == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign in with email',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create an account or sign in with Firebase credentials.',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'you@example.com',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                hintText: 'At least 6 characters',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: _isAuthBusy
                                      ? null
                                      : _signInWithEmail,
                                  child: _isAuthBusy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: _isAuthBusy
                                      ? null
                                      : _createAccount,
                                  child: const Text('Create Account'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.18,
                                  ),
                                  child: user.photoURL == null
                                      ? Icon(Icons.person, color: primaryColor)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName?.trim().isNotEmpty ==
                                                true
                                            ? user.displayName!
                                            : 'Signed in user',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email ?? 'No email available',
                                        style: TextStyle(
                                          color: textColor.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 200,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryColor,
                                ),
                                onPressed: _isAuthBusy ? null : _signOut,
                                child: _isAuthBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Sign Out',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedPageIndex) {
      case 0:
        return _buildAssessmentsPage();
      case 1:
        return _buildCalendarPage();
      case 2:
        return _buildSettingsPage();
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

          titleTextStyle: GoogleFonts.lato(fontSize: 24, color: Colors.white),
        ),

        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: darkPrimaryColor,
          titleTextStyle: GoogleFonts.lato(fontSize: 24, color: Colors.white),
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

                textAlign: TextAlign.left,

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
                thumbColor: darkMode
                    ? WidgetStateProperty.all(Colors.black)
                    : WidgetStateProperty.all(primaryColor),
                trackColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.5),
                ),
                thumbIcon: darkMode
                    ? const WidgetStatePropertyAll(Icon(Icons.dark_mode))
                    : const WidgetStatePropertyAll(Icon(Icons.light_mode)),
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
              label: 'Calendar',
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
