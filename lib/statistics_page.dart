
import 'package:flutter/material.dart';

class StatisticsPage extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;

  const StatisticsPage({
    super.key,
    required this.tasks,
  });

  DateTime? getDeadline(Map<String, dynamic> task) {
    final date = task['date'] as String?;
    final time = task['time'] as String?;

    if (date == null) return null;

    final parsed = DateTime.parse(date);

    if (time == null) {
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        23,
        59,
        59,
      );
    }

    final parts = time.split(':');

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Widget statisticCard(
    BuildContext context, {
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget priorityBar(
    String title,
    int count,
    int total,
    Color color,
  ) {
    final progress = total == 0
        ? 0.0
        : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text('$count'),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(8),
            backgroundColor:
                color.withValues(alpha: 0.15),
            color: color,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final total = tasks.length;

    final completed = tasks
        .where((task) => task['done'] == true)
        .length;

    final pending = total - completed;

    final overdue = tasks.where((task) {
      if (task['done'] == true) return false;

      final deadline = getDeadline(task);

      return deadline != null &&
          deadline.isBefore(now);
    }).length;

    final dueSoon = tasks.where((task) {
      if (task['done'] == true) return false;

      final deadline = getDeadline(task);

      if (deadline == null) return false;

      final difference = deadline.difference(now);

      return difference > Duration.zero &&
          difference <= const Duration(hours: 24);
    }).length;

    final highPriority = tasks
        .where((task) => task['priority'] == 'Wysoki')
        .length;

    final mediumPriority = tasks
        .where((task) =>
            task['priority'] == 'Średni' ||
            task['priority'] == null)
        .length;

    final lowPriority = tasks
        .where((task) => task['priority'] == 'Niski')
        .length;

    final completionRate = total == 0
        ? 0.0
        : completed / total;

    final completionPercent =
        (completionRate * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 850,
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Podsumowanie zadań',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Sprawdź swoje postępy i priorytety.',
              ),

              const SizedBox(height: 20),

              // Cztery karty statystyk
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                children: [
                  statisticCard(
                    context,
                    title: 'Wszystkie',
                    value: total,
                    icon: Icons.list_alt,
                    color: Colors.blue,
                  ),
                  statisticCard(
                    context,
                    title: 'Wykonane',
                    value: completed,
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  statisticCard(
                    context,
                    title: 'Do zrobienia',
                    value: pending,
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                  statisticCard(
                    context,
                    title: 'Po terminie',
                    value: overdue,
                    icon: Icons.warning_amber,
                    color: Colors.red,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Procent wykonanych zadań
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Skuteczność',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        '$completionPercent%',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 12),

                      LinearProgressIndicator(
                        value: completionRate,
                        minHeight: 12,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        '$completed z $total zadań wykonanych',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Statystyki priorytetów
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zadania według priorytetu',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      priorityBar(
                        'Wysoki',
                        highPriority,
                        total,
                        Colors.red,
                      ),

                      priorityBar(
                        'Średni',
                        mediumPriority,
                        total,
                        Colors.orange,
                      ),

                      priorityBar(
                        'Niski',
                        lowPriority,
                        total,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Zbliżające się terminy
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    'Terminy w ciągu 24 godzin',
                  ),
                  trailing: Text(
                    '$dueSoon',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (total == 0)
                const Center(
                  child: Text(
                    'Dodaj pierwsze zadanie, '
                    'aby zobaczyć statystyki.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
