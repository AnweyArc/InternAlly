import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';

enum ViewMode { list, calendar }

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color _primaryColor = Colors.blue;
  Color _backgroundColor = Colors.white;
  Color _accentColor = Colors.black;
  Color _secondAccentColor = Colors.grey;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _primaryColor = Color(prefs.getInt('primaryColor') ?? Colors.blue.value);
      _backgroundColor = Color(
        prefs.getInt('backgroundColor') ?? Colors.white.value,
      );
      _accentColor = Color(prefs.getInt('accentColor') ?? Colors.black.value);
      _secondAccentColor = Color(
        prefs.getInt('secondAccentColor') ?? Colors.grey.value,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InternAlly',
      theme: ThemeData(
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(secondary: _primaryColor.withOpacity(0.8)),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: _accentColor),
          bodyMedium: TextStyle(color: _accentColor),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColor,
          titleTextStyle: TextStyle(
            color: _accentColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _primaryColor,
        ),
      ),
      home: TimeTrackerScreen(onThemeUpdated: _loadTheme),
    );
  }
}

class TimeEntry {
  DateTime date;
  TimeOfDay timeIn;
  TimeOfDay? timeOut;

  TimeEntry({required this.date, required this.timeIn, this.timeOut});

  double get duration {
    if (timeOut == null) return 0.0;

    // Convert times to minutes since midnight
    final inMinutes = timeIn.hour * 60 + timeIn.minute;
    final outMinutes = timeOut!.hour * 60 + timeOut!.minute;

    // Calculate total minutes worked
    double totalMinutes = (outMinutes - inMinutes).toDouble();

    // Define lunch time (12 PM to 1 PM = 720 to 780 minutes)
    const lunchStart = 720;
    const lunchEnd = 780;

    // Calculate overlap with lunch time
    final overlapStart = max(inMinutes, lunchStart);
    final overlapEnd = min(outMinutes, lunchEnd);
    final lunchOverlap = max(0, overlapEnd - overlapStart);

    // Subtract lunch time if there's any overlap
    totalMinutes -= lunchOverlap.toDouble();

    // Convert to hours and ensure non-negative
    return max(totalMinutes / 60, 0.0);
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'timeIn': {'hour': timeIn.hour, 'minute': timeIn.minute},
    'timeOut':
        timeOut != null
            ? {'hour': timeOut!.hour, 'minute': timeOut!.minute}
            : null,
  };

  factory TimeEntry.fromJson(Map<String, dynamic> json) => TimeEntry(
    date: DateTime.parse(json['date']),
    timeIn: TimeOfDay(
      hour: json['timeIn']['hour'],
      minute: json['timeIn']['minute'],
    ),
    timeOut:
        json['timeOut'] != null
            ? TimeOfDay(
              hour: json['timeOut']['hour'],
              minute: json['timeOut']['minute'],
            )
            : null,
  );
}

class TimeTrackerScreen extends StatefulWidget {
  final VoidCallback onThemeUpdated;

  TimeTrackerScreen({required this.onThemeUpdated});

  @override
  _TimeTrackerScreenState createState() => _TimeTrackerScreenState();
}

class _TimeTrackerScreenState extends State<TimeTrackerScreen> {
  List<TimeEntry> _entries = [];
  Set<TimeEntry> _selectedEntries = {};
  double? _targetHours;
  late TextEditingController _targetController;
  ViewMode _viewMode = ViewMode.list;

  late Color currentAccent;
  late Color currentPrimary;
  late Color currentBackground;
  late Color currentSecondAccent;

  double get _selectedTotal =>
      _selectedEntries.fold(0.0, (sum, entry) => sum + entry.duration);

  @override
  void initState() {
    super.initState();
    _loadThemeColors();
    _targetController = TextEditingController();
    _loadData();
  }

  Future<void> _loadThemeColors() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentPrimary = Color(prefs.getInt('primaryColor') ?? Colors.blue.value);
      currentBackground = Color(
        prefs.getInt('backgroundColor') ?? Colors.white.value,
      );
      currentAccent = Color(prefs.getInt('accentColor') ?? Colors.black.value);
      currentSecondAccent = Color(
        // Add this line
        prefs.getInt('secondAccentColor') ?? Colors.grey.value,
      );
    });
  }

  void _showEntriesForDate(DateTime date) {
    final entries =
        _entries
            .where(
              (e) =>
                  e.date.year == date.year &&
                  e.date.month == date.month &&
                  e.date.day == date.day,
            )
            .toList();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Entries for ${DateFormat.yMMMd().format(date)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      title: Text(
                        '${entry.timeIn.format(context)} - ${entry.timeOut?.format(context) ?? 'N/A'}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        'Duration: ${entry.duration.toStringAsFixed(2)}h',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _editEntry(entry);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _entries.remove(entry);
                                _selectedEntries.remove(entry);
                                _saveEntries();
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatTile(String label, String formattedTime, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          formattedTime,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color, // Use the passed color parameter
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChip(
    BuildContext context,
    String label,
    String time,
    Color color, {
    bool compact = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isUltraCompact =
        screenWidth < 300; // New breakpoint for very small screens
    final fontSize =
        isUltraCompact
            ? 9.0
            : compact
            ? 10.0
            : 12.0;
    final padding =
        isUltraCompact
            ? EdgeInsets.symmetric(horizontal: 6, vertical: 2)
            : compact
            ? EdgeInsets.symmetric(horizontal: 6, vertical: 3)
            : EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isUltraCompact ? 12 : 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isUltraCompact) // Hide dot in ultra compact mode
            Container(
              width: compact ? 4 : 6,
              height: compact ? 4 : 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (!isUltraCompact) SizedBox(width: compact ? 3 : 4),
          Text(
            isUltraCompact
                ? time.replaceAll(' ', '')
                : // Remove spaces for AM/PM
                compact
                ? time
                : '$label:${compact ? '' : ' '}$time',
            style: TextStyle(
              fontSize: 8,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              letterSpacing: isUltraCompact ? -0.3 : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChipRow(BuildContext context, TimeEntry entry) {
    final isCompact = MediaQuery.of(context).size.width < 350;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _buildTimeChip(
          context,
          'IN',
          entry.timeIn.format(context),
          Theme.of(context).primaryColor,
          compact: isCompact,
        ),
        _buildTimeChip(
          context,
          'OUT',
          entry.timeOut?.format(context) ?? 'N/A',
          Colors.orangeAccent,
          compact: isCompact,
        ),
      ],
    );
  }

  void _openColorPicker() async {
    final prefs = await SharedPreferences.getInstance();
    Color currentPrimary = Color(
      prefs.getInt('primaryColor') ?? Colors.blue.value,
    );
    Color currentBackground = Color(
      prefs.getInt('backgroundColor') ?? Colors.white.value,
    );
    Color currentAccent = Color(
      prefs.getInt('accentColor') ?? Colors.black.value,
    );
    Color currentSecondAccent = Color(
      prefs.getInt('secondAccentColor') ?? Colors.grey.value,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Theme Customization',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Theme.of(context).dividerColor, thickness: 1),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildColorSection(
                  context,
                  title: '🎨 Primary Color',
                  currentColor: currentPrimary,
                  onChanged: (color) => currentPrimary = color,
                ),
                _buildColorSection(
                  context,
                  title: '🌅 Background Color',
                  currentColor: currentBackground,
                  onChanged: (color) => currentBackground = color,
                ),
                _buildColorSection(
                  context,
                  title: '✨ Main Accent',
                  currentColor: currentAccent,
                  onChanged: (color) => currentAccent = color,
                ),
                _buildColorSection(
                  context,
                  title: '💎 Second Accent',
                  currentColor: currentSecondAccent,
                  onChanged: (color) => currentSecondAccent = color,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await prefs.setInt('primaryColor', currentPrimary.value);
                    await prefs.setInt(
                      'backgroundColor',
                      currentBackground.value,
                    );
                    await prefs.setInt('accentColor', currentAccent.value);
                    await prefs.setInt(
                      'secondAccentColor',
                      currentSecondAccent.value,
                    );
                    widget.onThemeUpdated();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString('entries');
    if (entriesJson != null) {
      final List<dynamic> decoded = jsonDecode(entriesJson);
      _entries = decoded.map((item) => TimeEntry.fromJson(item)).toList();
    }
    _targetHours = prefs.getDouble('targetHours');
    _targetController.text = _targetHours?.toString() ?? '';
    setState(() {});
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('entries', entriesJson);
  }

  void _deleteEntry(int index) {
    setState(() {
      final entryIndex = _entries.length - 1 - index;
      final entryToRemove = _entries[entryIndex];
      _entries.removeAt(entryIndex);
      _selectedEntries.remove(entryToRemove);
      _saveEntries();
    });
  }

  double _convertToHours(int hours, int minutes) {
    return hours + minutes / 60;
  }

  // Add this helper method to format decimal hours to h.mm format
  String _formatHours(double hours) {
    int totalMinutes = (hours * 60).round();
    int h = totalMinutes ~/ 60;
    int m = totalMinutes % 60;
    return '${h.toString().padLeft(2, ' ')}h ${m.toString().padLeft(2, '0')}m';
  }

  double get _totalHours =>
      _entries.fold(0.0, (sum, entry) => sum + entry.duration);

  double get _remainingHours =>
      _targetHours != null ? max(_targetHours! - _totalHours, 0.0) : 0.0;

  void _setTarget(String value) async {
    final parts = value.split('.');
    int hours = int.tryParse(parts[0]) ?? 0;
    int minutes =
        parts.length > 1
            ? int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0
            : 0;

    if (minutes > 59) minutes = 59;

    final target = _convertToHours(hours, minutes);

    if (target >= 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('targetHours', target);
      setState(() => _targetHours = target);
    }
  }

  Map<DateTime, List<TimeEntry>> _groupEntriesByDate() {
    final groupedEntries = <DateTime, List<TimeEntry>>{};
    for (final entry in _entries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      groupedEntries.putIfAbsent(date, () => []).add(entry);
    }
    return groupedEntries;
  }

  Widget _buildColorSection(
    BuildContext context, {
    required String title,
    required Color currentColor,
    required ValueChanged<Color> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ColorPicker(
            pickerColor: currentColor,
            onColorChanged: onChanged,
            showLabel: false,
            pickerAreaHeightPercent: 0.2,
            displayThumbColor: true,
            portraitOnly: true,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(16),
            hexInputBar: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    final groupedEntries = _groupEntriesByDate();
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingWeekday = firstDay.weekday;
    final cellSize =
        (MediaQuery.of(context).size.width - 24) /
        7; // Calculate square size based on screen width

    return SingleChildScrollView(
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        children: [
          TableRow(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            children:
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (day) => Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: currentSecondAccent),
                        ),
                      ),
                    )
                    .toList(),
          ),
          ...List.generate(
            ((daysInMonth + startingWeekday - 1) / 7).ceil(),
            (weekIndex) => TableRow(
              children: List.generate(7, (dayIndex) {
                final dayNumber =
                    weekIndex * 7 + dayIndex - startingWeekday + 2;
                final isCurrentMonth =
                    dayNumber > 0 && dayNumber <= daysInMonth;
                final currentDate =
                    isCurrentMonth
                        ? DateTime(now.year, now.month, dayNumber)
                        : null;

                return GestureDetector(
                  onTap: () {
                    if (currentDate != null &&
                        groupedEntries.containsKey(currentDate)) {
                      _showEntriesForDate(currentDate);
                    }
                  },
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.all(2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Container(
                      height: cellSize, // Use calculated square size
                      padding: EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              isCurrentMonth ? dayNumber.toString() : '',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          if (currentDate != null &&
                              groupedEntries.containsKey(currentDate))
                            Expanded(
                              child: ListView.builder(
                                physics: const ClampingScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: groupedEntries[currentDate]!.length,
                                itemBuilder: (context, index) {
                                  final entry =
                                      groupedEntries[currentDate]![index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.access_time_rounded,
                                                  size: 14,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Flexible(
                                                child: RichText(
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text:
                                                            '${entry.timeIn.format(context)}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyLarge
                                                                  ?.color,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: ' → ',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .bodyLarge
                                                              ?.color
                                                              ?.withOpacity(
                                                                0.5,
                                                              ),
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            entry.timeOut
                                                                ?.format(
                                                                  context,
                                                                ) ??
                                                            'N/A',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .bodyLarge
                                                              ?.color
                                                              ?.withOpacity(
                                                                0.9,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            '${entry.duration.toStringAsFixed(2)} hours',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color
                                                  ?.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (currentDate != null &&
                              groupedEntries.containsKey(currentDate) &&
                              groupedEntries[currentDate]!.isEmpty)
                            Expanded(
                              child: Center(
                                child: Text(
                                  'No entries',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                        ?.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'InternAlly',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: currentSecondAccent, // Use the state variable
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    DateFormat.EEEE().format(DateTime.now()),
                    style: TextStyle(
                      color: currentSecondAccent.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    height: 14,
                    width: 1,
                    color: currentAccent.withOpacity(0.4),
                  ),
                  SizedBox(width: 8),
                  Text(
                    DateFormat.MMMMd().format(DateTime.now()),
                    style: TextStyle(
                      color: currentAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: currentAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: currentAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      currentAccent.withOpacity(0.3),
                      currentAccent.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _viewMode == ViewMode.list
                      ? Icons.calendar_month
                      : Icons.list,
                  size: 24,
                  color: currentAccent,
                ),
              ),
              onPressed:
                  () => setState(() {
                    _viewMode =
                        _viewMode == ViewMode.list
                            ? ViewMode.calendar
                            : ViewMode.list;
                  }),
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: currentAccent.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: currentAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.color_lens, size: 24),
              color: currentAccent,
              onPressed: _openColorPicker,
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                currentAccent.withOpacity(0.2),
                currentAccent.withOpacity(0.1),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTimeEntry,
        child: Icon(Icons.add, size: 28),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Hours',
                    labelStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.save_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () => _setTarget(_targetController.text),
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 16,
                  ),
                  onSubmitted: _setTarget,
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatTile(
                  'Total',
                  _formatHours(_totalHours),
                  currentSecondAccent, // Add this parameter
                ),
                _buildStatTile(
                  'Remaining',
                  _formatHours(_remainingHours),
                  currentSecondAccent, // Add this parameter
                ),
                _buildStatTile(
                  'Selected',
                  _formatHours(_selectedTotal),
                  currentSecondAccent, // Add this parameter
                ),
              ],
            ),
            SizedBox(height: 24),
            Expanded(
              child:
                  _viewMode == ViewMode.list
                      ? ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder:
                            (context, index) => SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = _entries.reversed.toList()[index];
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        _selectedEntries.contains(entry)
                                            ? Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.2)
                                            : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Checkbox(
                                    value: _selectedEntries.contains(entry),
                                    onChanged:
                                        (bool? value) => setState(() {
                                          value == true
                                              ? _selectedEntries.add(entry)
                                              : _selectedEntries.remove(entry);
                                        }),
                                    activeColor: Theme.of(context).primaryColor,
                                    shape: CircleBorder(),
                                  ),
                                ),
                                title: Text(
                                  DateFormat.yMMMd().format(entry.date),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                subtitle: Column(
                                  // Only one subtitle parameter
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: [
                                            _buildTimeChip(
                                              context,
                                              'IN',
                                              entry.timeIn.format(context),
                                              Theme.of(context).primaryColor,
                                              compact:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  350,
                                            ),
                                            _buildTimeChip(
                                              context,
                                              'OUT',
                                              entry.timeOut?.format(context) ??
                                                  'N/A',
                                              Colors.orangeAccent,
                                              compact:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  350,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  // Separate trailing parameter
                                  width: 100,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _formatHours(entry.duration),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Container(
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.delete_rounded,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _deleteEntry(index),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _editEntry(entry),
                              ),
                            ),
                          );
                        },
                      )
                      : _buildCalendarView(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTimeEntry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (date == null) return;

    // Time In Picker with enhanced styling
    final timeIn = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Select Time In',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              child!,
            ],
          ),
        );
      },
    );
    if (timeIn == null) return;

    // Time Out Picker with enhanced styling
    final timeOut = await showTimePicker(
      context: context,
      initialTime: timeIn,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Select Time Out',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              child!,
            ],
          ),
        );
      },
    );
    if (timeOut == null) return;

    final newEntry = TimeEntry(date: date, timeIn: timeIn, timeOut: timeOut);
    setState(() {
      _entries.add(newEntry);
      _saveEntries();
    });
  }

  Future<void> _editEntry(TimeEntry entry) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    final newTimeIn = await showTimePicker(
      context: context,
      initialTime: entry.timeIn,
    );

    final newTimeOut = await showTimePicker(
      context: context,
      initialTime: entry.timeOut ?? TimeOfDay.now(),
    );

    if (newDate != null && newTimeIn != null && newTimeOut != null) {
      setState(() {
        entry.date = newDate;
        entry.timeIn = newTimeIn;
        entry.timeOut = newTimeOut;
        _saveEntries();
      });
    }
  }
}
