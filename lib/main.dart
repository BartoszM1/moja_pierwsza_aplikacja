
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'statistics_page.dart';

void main() {
  runApp(const MyApp());
}

// ==========================================
// APLIKACJA I MOTYW
// ==========================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> toggleTheme() async {
    final newValue = !isDarkMode;

    setState(() {
      isDarkMode = newValue;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', newValue);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Moje zadania',
      themeMode:
          isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor:
            const Color(0xFFF5F8F5),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor:
            const Color(0xFF141C1A),
      ),
      home: HomePage(
        isDarkMode: isDarkMode,
        onThemeChanged: toggleTheme,
      ),
    );
  }
}

// ==========================================
// EKRAN GŁÓWNY
// ==========================================

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeChanged;

  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> tasks = [];

  bool isLoading = true;
  bool remindersEnabled = true;

  String selectedFilter = 'Wszystkie';
  String selectedSort = 'Najbliższy termin';
  String newTaskPriority = 'Średni';

  DateTime currentTime = DateTime.now();
  Timer? reminderTimer;

  final TextEditingController controller =
      TextEditingController();

  final List<String> priorities = [
    'Niski',
    'Średni',
    'Wysoki',
  ];

  @override
  void initState() {
    super.initState();

    loadTasks();

    reminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          currentTime = DateTime.now();
        });
      },
    );
  }

  // ==========================================
  // WCZYTYWANIE I ZAPISYWANIE
  // ==========================================

  Future<void> loadTasks() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final savedTasks = prefs.getString('tasks');

      if (!mounted) return;

      setState(() {
        remindersEnabled =
            prefs.getBool('remindersEnabled') ?? true;

        if (savedTasks != null) {
          final List<dynamic> decoded =
              jsonDecode(savedTasks);

          tasks = decoded.map((item) {
            final task =
                Map<String, dynamic>.from(item as Map);

            task.putIfAbsent('date', () => null);
            task.putIfAbsent(
              'priority',
              () => 'Średni',
            );
            task.putIfAbsent('time', () => null);

            return task;
          }).toList();
        } else {
          tasks = [
            {
              'title': 'Nauczyć się Fluttera',
              'done': false,
              'date': null,
              'time': null,
              'priority': 'Średni',
            },
            {
              'title': 'Poznać język Dart',
              'done': false,
              'date': null,
              'time': null,
              'priority': 'Średni',
            },
          ];
        }

        currentTime = DateTime.now();
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Błąd odczytu danych: $error');
    }
  }

  Future<void> saveTasks() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final snapshot = jsonEncode(tasks);

      final success =
          await prefs.setString('tasks', snapshot);

      if (!success) {
        throw Exception(
          'Nie udało się zapisać danych',
        );
      }
    } catch (error) {
      if (!mounted) return;

      showMessage('Błąd zapisu: $error');
    }
  }

  Future<void> toggleReminders(bool value) async {
    setState(() {
      remindersEnabled = value;
    });

    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setBool(
        'remindersEnabled',
        value,
      );
    } catch (error) {
      if (!mounted) return;

      showMessage(
        'Błąd zapisu ustawień: $error',
      );
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================
  // DATY I GODZINY
  // ==========================================

  String formatDate(String date) {
    final parsed = DateTime.parse(date);

    return '${parsed.day.toString().padLeft(2, '0')}.'
        '${parsed.month.toString().padLeft(2, '0')}.'
        '${parsed.year}';
  }

  String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  DateTime? getDeadline(
    Map<String, dynamic> task,
  ) {
    final date = task['date'] as String?;
    final time = task['time'] as String?;

    if (date == null) return null;

    final parsedDate = DateTime.parse(date);

    if (time == null) {
      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        23,
        59,
        59,
      );
    }

    final parts = time.split(':');

    return DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  bool isOverdue(
    Map<String, dynamic> task,
  ) {
    if (task['done'] == true) return false;

    final deadline = getDeadline(task);

    if (deadline == null) return false;

    return deadline.isBefore(currentTime);
  }

  bool isDueSoon(
    Map<String, dynamic> task,
  ) {
    if (task['done'] == true) return false;

    final deadline = getDeadline(task);

    if (deadline == null) return false;

    final difference =
        deadline.difference(currentTime);

    return difference > Duration.zero &&
        difference <= const Duration(hours: 24);
  }

  String deadlineText(
    Map<String, dynamic> task,
  ) {
    final date = task['date'] as String?;
    final time = task['time'] as String?;

    if (date == null) {
      return 'Bez terminu';
    }

    final formattedDate = formatDate(date);

    if (time == null) {
      return formattedDate;
    }

    return '$formattedDate, godz. $time';
  }

  // ==========================================
  // PRIORYTETY
  // ==========================================

  Color priorityColor(String priority) {
    switch (priority) {
      case 'Wysoki':
        return Colors.red;
      case 'Średni':
        return Colors.orange;
      case 'Niski':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  int priorityValue(String priority) {
    switch (priority) {
      case 'Wysoki':
        return 3;
      case 'Średni':
        return 2;
      case 'Niski':
        return 1;
      default:
        return 0;
    }
  }

  // ==========================================
  // OPERACJE NA ZADANIACH
  // ==========================================

  void addTask() {
    final title = controller.text.trim();

    if (title.isEmpty) return;

    setState(() {
      tasks.add({
        'title': title,
        'done': false,
        'date': null,
        'time': null,
        'priority': newTaskPriority,
      });

      controller.clear();
      newTaskPriority = 'Średni';
    });

    saveTasks();
  }

  void deleteTask(
    Map<String, dynamic> task,
  ) {
    setState(() {
      tasks.remove(task);
    });

    saveTasks();
  }

  void toggleTask(
    Map<String, dynamic> task,
    bool value,
  ) {
    setState(() {
      task['done'] = value;
    });

    saveTasks();
  }

  Future<void> editTask(
    Map<String, dynamic> task,
  ) async {
    final editController =
        TextEditingController(
      text: task['title'] as String,
    );

    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edytuj zadanie'),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nazwa zadania',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.pop(
                dialogContext,
                value,
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  editController.text,
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );

    editController.dispose();

    if (!mounted || newTitle == null) return;
    if (!tasks.contains(task)) return;

    final title = newTitle.trim();

    if (title.isEmpty) return;

    setState(() {
      task['title'] = title;
    });

    await saveTasks();
  }

  Future<void> editPriority(
    Map<String, dynamic> task,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Wybierz priorytet'),
          children: priorities.map((priority) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  priority,
                );
              },
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 14,
                    color: priorityColor(priority),
                  ),
                  const SizedBox(width: 12),
                  Text(priority),
                ],
              ),
            );
          }).toList(),
        );
      },
    );

    if (!mounted || selected == null) return;
    if (!tasks.contains(task)) return;

    setState(() {
      task['priority'] = selected;
    });

    await saveTasks();
  }

  Future<void> selectTaskDate(
    Map<String, dynamic> task,
  ) async {
    final savedDate =
        task['date'] as String?;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: savedDate != null
          ? DateTime.parse(savedDate)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Wybierz termin wykonania',
    );

    if (!mounted || selectedDate == null) return;
    if (!tasks.contains(task)) return;

    final dateString =
        '${selectedDate.year}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';

    setState(() {
      task['date'] = dateString;
      currentTime = DateTime.now();
    });

    await saveTasks();
  }

  Future<void> selectTaskTime(
    Map<String, dynamic> task,
  ) async {
    if (task['date'] == null) {
      showMessage(
        'Najpierw ustaw datę zadania',
      );
      return;
    }

    final savedTime =
        task['time'] as String?;

    TimeOfDay initialTime = TimeOfDay.now();

    if (savedTime != null) {
      final parts = savedTime.split(':');

      initialTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Wybierz godzinę wykonania',
    );

    if (!mounted || selectedTime == null) return;
    if (!tasks.contains(task)) return;

    setState(() {
      task['time'] = formatTime(selectedTime);
      currentTime = DateTime.now();
    });

    await saveTasks();
  }

  // ==========================================
  // FILTROWANIE I SORTOWANIE
  // ==========================================

  List<Map<String, dynamic>> getVisibleTasks() {
    List<Map<String, dynamic>> visible =
        List.from(tasks);

    switch (selectedFilter) {
      case 'Do zrobienia':
        visible = visible
            .where(
              (task) => task['done'] == false,
            )
            .toList();
        break;

      case 'Wykonane':
        visible = visible
            .where(
              (task) => task['done'] == true,
            )
            .toList();
        break;

      case 'Po terminie':
        visible =
            visible.where(isOverdue).toList();
        break;
    }

    switch (selectedSort) {
      case 'Najbliższy termin':
        visible.sort((a, b) {
          final aDeadline = getDeadline(a);
          final bDeadline = getDeadline(b);

          if (aDeadline == null &&
              bDeadline == null) {
            return 0;
          }

          if (aDeadline == null) return 1;
          if (bDeadline == null) return -1;

          return aDeadline.compareTo(bDeadline);
        });
        break;

      case 'Najdalszy termin':
        visible.sort((a, b) {
          final aDeadline = getDeadline(a);
          final bDeadline = getDeadline(b);

          if (aDeadline == null &&
              bDeadline == null) {
            return 0;
          }

          if (aDeadline == null) return 1;
          if (bDeadline == null) return -1;

          return bDeadline.compareTo(aDeadline);
        });
        break;

      case 'Alfabetycznie A-Z':
        visible.sort((a, b) {
          return (a['title'] as String)
              .toLowerCase()
              .compareTo(
                (b['title'] as String)
                    .toLowerCase(),
              );
        });
        break;

      case 'Najnowsze':
        visible =
            visible.reversed.toList();
        break;

      case 'Priorytet':
        visible.sort((a, b) {
          final aPriority = priorityValue(
            a['priority'] as String,
          );

          final bPriority = priorityValue(
            b['priority'] as String,
          );

          return bPriority.compareTo(aPriority);
        });
        break;
    }

    return visible;
  }

  // ==========================================
  // PANEL PRZYPOMNIEŃ
  // ==========================================

  Widget buildRemindersPanel() {
    if (!remindersEnabled) {
      return const SizedBox.shrink();
    }

    final overdueTasks =
        tasks.where(isOverdue).toList();

    final dueSoonTasks =
        tasks.where(isDueSoon).toList();

    if (overdueTasks.isEmpty &&
        dueSoonTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notifications_active),
                SizedBox(width: 8),
                Text(
                  'Przypomnienia',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (overdueTasks.isNotEmpty)
              Text(
                'Po terminie: '
                '${overdueTasks.length}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),

            if (dueSoonTasks.isNotEmpty)
              Text(
                'Termin w ciągu 24 godzin: '
                '${dueSoonTasks.length}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 8),

            ...[
              ...overdueTasks,
              ...dueSoonTasks,
            ].take(3).map((task) {
              final overdue = isOverdue(task);

              return Padding(
                padding: const EdgeInsets.only(
                  top: 5,
                ),
                child: Row(
                  children: [
                    Icon(
                      overdue
                          ? Icons.warning_amber
                          : Icons.schedule,
                      size: 18,
                      color: overdue
                          ? Colors.red
                          : Colors.orange,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        '${task['title']} – '
                        '${deadlineText(task)}',
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

  // ==========================================
  // POJEDYNCZA KARTA ZADANIA
  // ==========================================

  Widget buildTaskCard(
    Map<String, dynamic> task,
  ) {
    final done = task['done'] == true;
    final overdue = isOverdue(task);
    final dueSoon = isDueSoon(task);

    final priority =
        task['priority'] as String;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Checkbox(
              value: done,
              onChanged: (value) {
                toggleTask(
                  task,
                  value ?? false,
                );
              },
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    deadlineText(task),
                    style: TextStyle(
                      fontSize: 12,
                      color: overdue
                          ? Colors.red
                          : dueSoon
                              ? Colors.orange
                              : Colors.grey,
                    ),
                  ),

                  if (remindersEnabled &&
                      (overdue || dueSoon))
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 5,
                      ),
                      child: Text(
                        overdue
                            ? 'Po terminie!'
                            : 'Termin w ciągu 24 godzin',
                        style: TextStyle(
                          color: overdue
                              ? Colors.red
                              : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor(priority)
                          .withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      priority,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: priorityColor(
                          priority,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              tooltip: 'Opcje zadania',
              icon: const Icon(
                Icons.more_vert,
              ),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    editTask(task);
                    break;

                  case 'date':
                    selectTaskDate(task);
                    break;

                  case 'time':
                    selectTaskTime(task);
                    break;

                  case 'priority':
                    editPriority(task);
                    break;

                  case 'delete':
                    deleteTask(task);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edytuj nazwę'),
                ),
                const PopupMenuItem(
                  value: 'date',
                  child: Text('Ustaw datę'),
                ),
                const PopupMenuItem(
                  value: 'time',
                  child: Text('Ustaw godzinę'),
                ),
                const PopupMenuItem(
                  value: 'priority',
                  child: Text('Zmień priorytet'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Usuń'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ZAMYKANIE WIDGETU
  // ==========================================

  @override
  void dispose() {
    reminderTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  // ==========================================
  // WYGLĄD EKRANU
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final completedTasks = tasks
        .where(
          (task) => task['done'] == true,
        )
        .length;

    final progress = tasks.isEmpty
        ? 0.0
        : completedTasks / tasks.length;

    final progressPercent =
        (progress * 100).round();

    final visibleTasks = getVisibleTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje zadania'),
        backgroundColor: Colors.transparent,
        actions: [
          // STATYSTYKI
          IconButton(
            tooltip: 'Statystyki',
            icon: const Icon(
              Icons.bar_chart,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      StatisticsPage(
                    tasks: tasks,
                  ),
                ),
              );
            },
          ),

          // TRYB CIEMNY
          IconButton(
            tooltip: widget.isDarkMode
                ? 'Włącz tryb jasny'
                : 'Włącz tryb ciemny',
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.onThemeChanged,
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 850,
                ),

                // ==================================
                // JEDNA PRZEWIJANA STRONA
                // ==================================
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'MÓJ ORGANIZER',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Zaplanuj swój dzień',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PANEL POSTĘPU
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF196B4D),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TWÓJ POSTĘP',
                            style: TextStyle(
                              color: Color(0xFFC9EBD6),
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              Text(
                                '$completedTasks z '
                                '${tasks.length} zadań',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              Text(
                                '$progressPercent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                            backgroundColor:
                                const Color(0xFF5A9275),
                            color:
                                const Color(0xFFC3F3B8),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PRZYPOMNIENIA
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Przypomnienia',
                      ),
                      subtitle: const Text(
                        'Ostrzeżenia o terminach zadań',
                      ),
                      secondary: const Icon(
                        Icons.notifications_outlined,
                      ),
                      value: remindersEnabled,
                      onChanged: toggleReminders,
                    ),

                    buildRemindersPanel(),

                    const SizedBox(height: 12),

                    // DODAWANIE ZADANIA
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText:
                                  'Nowe zadanie...',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            onSubmitted: (_) =>
                                addTask(),
                          ),
                        ),

                        const SizedBox(width: 8),

                        FilledButton(
                          onPressed: addTask,
                          child: const Icon(
                            Icons.add,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // PRIORYTET NOWEGO ZADANIA
                    Row(
                      children: [
                        const Text('Priorytet: '),

                        const SizedBox(width: 10),

                        DropdownButton<String>(
                          value: newTaskPriority,
                          items: priorities
                              .map((priority) {
                            return DropdownMenuItem(
                              value: priority,
                              child: Text(priority),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              newTaskPriority = value;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // FILTROWANIE
                    SingleChildScrollView(
                      scrollDirection:
                          Axis.horizontal,
                      child: Row(
                        children: [
                          'Wszystkie',
                          'Do zrobienia',
                          'Wykonane',
                          'Po terminie',
                        ].map((filter) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              right: 8,
                            ),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected:
                                  selectedFilter ==
                                      filter,
                              onSelected: (_) {
                                setState(() {
                                  selectedFilter =
                                      filter;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // SORTOWANIE
                    DropdownButtonFormField<String>(
                      initialValue: selectedSort,
                      decoration: InputDecoration(
                        labelText: 'Sortuj zadania',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      items: [
                        'Najbliższy termin',
                        'Najdalszy termin',
                        'Alfabetycznie A-Z',
                        'Najnowsze',
                        'Priorytet',
                      ].map((sort) {
                        return DropdownMenuItem(
                          value: sort,
                          child: Text(sort),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          selectedSort = value;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // NAGŁÓWEK LISTY
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        const Text(
                          'Lista zadań',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        Text(
                          '${visibleTasks.length} zadań',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ==================================
                    // LISTA ZADAŃ BEZ OSOBNEGO SCROLLA
                    // ==================================

                    if (visibleTasks.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical: 40,
                        ),
                        child: Center(
                          child: Text(
                            'Brak zadań w tej kategorii',
                          ),
                        ),
                      )
                    else
                      ...visibleTasks.map(
                        (task) =>
                            buildTaskCard(task),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
