import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../models/settings_model.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/responsive_layout.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalytics();
    });
  }

  void _loadAnalytics() {
    final provider = context.read<AttendanceProvider>();
    provider.fetchAnalytics(days: _selectedDays);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final padding = ResponsiveLayout.pagePadding(
      context,
      compact: 12,
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('analytics')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t('refresh'),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveLayout.contentMaxWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterHeader(t),
                const SizedBox(height: 24),
                Consumer<AttendanceProvider>(
                  builder: (context, provider, child) {
                    final analytics = provider.analyticsData;
                    if (analytics == null && provider.isLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 100),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (analytics == null) {
                      return Center(
                        child: Text(t('noDataAvailable')),
                      ).animate().fadeIn();
                    }

                    return Column(
                      children: [
                        _buildSummaryGrid(context, analytics, t),
                        const SizedBox(height: 24),
                        _buildMainCharts(context, analytics, t),
                        const SizedBox(height: 24),
                        _buildBreakdownSection(context, analytics, t),
                        const SizedBox(height: 48),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterHeader(dynamic t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, color: AppTheme.primaryLight, size: 20),
          const SizedBox(width: 12),
          Text(
            t('period'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDayChip(7, t('last7Days')),
                _buildDayChip(30, t('last30Days')),
                _buildDayChip(90, t('last90Days')),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildDayChip(int days, String label) {
    final isSelected = _selectedDays == days;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedDays = days);
        _loadAnalytics();
      },
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, AnalyticsData analytics, dynamic t) {
    final isMobile = ResponsiveLayout.isMobile(context);
    return GridView.count(
      crossAxisCount: ResponsiveLayout.gridColumns(
        context,
        compact: 1,
        mobile: 2,
        tablet: 2,
        desktop: 4,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isMobile ? 2.2 : 1.6,
      children: [
        _buildStatCard(
          t('totalRecords'),
          '${analytics.summary.total}',
          Icons.assessment_rounded,
          AppTheme.primaryColor,
          0,
        ),
        _buildStatCard(
          t('present'),
          '${analytics.summary.present}',
          Icons.check_circle_rounded,
          AppTheme.successColor,
          1,
        ),
        _buildStatCard(
          t('late'),
          '${analytics.summary.late}',
          Icons.access_time_filled_rounded,
          AppTheme.warningColor,
          2,
        ),
        _buildStatCard(
          t('absent'),
          '${analytics.summary.absent}',
          Icons.cancel_rounded,
          AppTheme.errorColor,
          3,
        ),
      ],
    );
  }

  Widget _buildMainCharts(BuildContext context, AnalyticsData analytics, dynamic t) {
    final useSplitCharts = ResponsiveLayout.width(context) >= 1100;

    if (useSplitCharts) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: _buildTrendChart(analytics, t)),
          const SizedBox(width: 20),
          Expanded(flex: 3, child: _buildDistributionChart(analytics, t)),
        ],
      );
    }

    return Column(
      children: [
        _buildTrendChart(analytics, t),
        const SizedBox(height: 20),
        _buildDistributionChart(analytics, t),
      ],
    );
  }

  Widget _buildTrendChart(AnalyticsData analytics, dynamic t) {
    return Container(
      height: 420,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('attendanceTrends'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _buildChartLegend(t),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.glassBorder,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 10,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: analytics.dailyTrend.length > 10 ? 5 : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= analytics.dailyTrend.length) return const SizedBox();
                        final dateStr = analytics.dailyTrend[index].date;
                        final day = dateStr.split('-').last;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            day,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _lineBarData(analytics, (d) => d.present.toDouble(), AppTheme.successColor),
                  _lineBarData(analytics, (d) => d.late.toDouble(), AppTheme.warningColor),
                  _lineBarData(analytics, (d) => d.absent.toDouble(), AppTheme.errorColor),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppTheme.bgCard,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toInt().toString(),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.98, 0.98));
  }

  LineChartBarData _lineBarData(AnalyticsData analytics, double Function(DailyTrend) getter, Color color) {
    return LineChartBarData(
      spots: analytics.dailyTrend.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), getter(e.value));
      }).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.01)],
        ),
      ),
    );
  }

  Widget _buildDistributionChart(AnalyticsData analytics, dynamic t) {
    return Container(
      height: 420,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('distribution'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 70,
                    startDegreeOffset: -90,
                    sections: [
                      _pieSection(analytics.summary.present.toDouble(), AppTheme.successColor, t('present'), analytics.summary.total),
                      _pieSection(analytics.summary.late.toDouble(), AppTheme.warningColor, t('late'), analytics.summary.total),
                      _pieSection(analytics.summary.absent.toDouble(), AppTheme.errorColor, t('absent'), analytics.summary.total),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${analytics.summary.attendanceRate.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(t('rate'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
          ),
          const SizedBox(height: 10),
          _buildPieLegend(analytics, t),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.98, 0.98));
  }

  PieChartSectionData _pieSection(double value, Color color, String title, int total) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0';
    return PieChartSectionData(
      color: color,
      value: value,
      title: '$pct%',
      radius: 30,
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildBreakdownSection(BuildContext context, AnalyticsData analytics, dynamic t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('departmentBreakdown'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ).animate().fadeIn(delay: 600.ms),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            children: analytics.departmentBreakdown.map((dept) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dept.department, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('${dept.percentage.toStringAsFixed(1)}%', style: TextStyle(color: dept.percentage > 80 ? AppTheme.successColor : AppTheme.warningColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: dept.percentage / 100,
                        minHeight: 8,
                        backgroundColor: AppTheme.bgElevated,
                        valueColor: AlwaysStoppedAnimation(dept.percentage > 80 ? AppTheme.successColor : AppTheme.warningColor),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.05, end: 0),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 200 + (index * 100))).slideX(begin: 0.1, end: 0);
  }

  Widget _buildChartLegend(dynamic t) {
    return Row(
      children: [
        _legendItem(t('present'), AppTheme.successColor),
        const SizedBox(width: 12),
        _legendItem(t('late'), AppTheme.warningColor),
        const SizedBox(width: 12),
        _legendItem(t('absent'), AppTheme.errorColor),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildPieLegend(AnalyticsData analytics, dynamic t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _pieLegendItem(t('present'), analytics.summary.present, AppTheme.successColor),
        _pieLegendItem(t('late'), analytics.summary.late, AppTheme.warningColor),
        _pieLegendItem(t('absent'), analytics.summary.absent, AppTheme.errorColor),
      ],
    );
  }

  Widget _pieLegendItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
