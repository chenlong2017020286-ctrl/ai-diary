import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MoodChart extends StatelessWidget {
  final Map<DateTime, double> moodData;

  const MoodChart({super.key, required this.moodData});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (moodData.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('暂无数据',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4))),
        ),
      );
    }

    final entries = moodData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.onSurface.withOpacity(0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == -1.0) return const Text('😢', style: TextStyle(fontSize: 12));
                  if (value == 0.0) return const Text('😐', style: TextStyle(fontSize: 12));
                  if (value == 1.0) return const Text('😊', style: TextStyle(fontSize: 12));
                  return const Text('');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (entries.length / 5).ceilToDouble().clamp(1, 100),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < entries.length) {
                    final date = entries[index].key;
                    return Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: entries.length <= 14,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withOpacity(0.08),
              ),
            ),
            // Zero reference line
            const LineChartBarData(
              spots: [FlSpot(0, 0), FlSpot(100, 0)],
              color: Colors.transparent,
              barWidth: 0,
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((s) {
                  final index = s.x.toInt();
                  if (index < entries.length) {
                    final score = entries[index].value;
                    final mood = score > 0.3 ? '😊' : score < -0.3 ? '😢' : '😐';
                    return LineTooltipItem(
                      '$mood ${score.toStringAsFixed(2)}',
                      TextStyle(color: colorScheme.onPrimary, fontSize: 12),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
