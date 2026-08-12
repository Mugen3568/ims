import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';

/// ReportsScreen — Production Analytics Hub for Institute Owners & Managers
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportService _reportService = ReportService();

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Filter selections
  String? _selectedClassId;
  String? _selectedClassName;
  String _timeRangeLabel = 'Last 30 Days';

  InstituteKpiSummary? _kpiSummary;
  AttendanceReportSummary? _attendanceSummary;
  ClassAnalyticsSummary? _classSummary;
  List<SubjectAnalyticsSummary> _subjectSummaries = [];
  List<TeacherPerformanceSummary> _teacherSummaries = [];
  List<FeeDefaulterEntry> _feeDefaulters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final kpi = await _reportService.getInstituteKpiSummary();

      DateTimeRange? range;
      final now = DateTime.now();
      if (_timeRangeLabel == 'Last 7 Days') {
        range = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      } else if (_timeRangeLabel == 'Last 30 Days') {
        range = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      }

      final attendance = await _reportService.getAttendanceReport(
        classId: _selectedClassId,
        dateRange: range,
      );

      final subjects = await _reportService.getSubjectAnalytics();
      final teachers = await _reportService.getTeacherPerformanceReport();
      final defaulters = await _reportService.getFeeDefaulters();

      ClassAnalyticsSummary? classSum;
      if (_selectedClassId != null && _selectedClassId!.isNotEmpty) {
        classSum = await _reportService.getClassAnalytics(
          _selectedClassId!,
          _selectedClassName ?? _selectedClassId!,
        );
      }

      if (mounted) {
        setState(() {
          _kpiSummary = kpi;
          _attendanceSummary = attendance;
          _subjectSummaries = subjects;
          _teacherSummaries = teachers;
          _feeDefaulters = defaulters;
          _classSummary = classSum;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV Reports',
            onPressed: () => _showExportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Analytics',
            onPressed: _loadAllAnalytics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0D47A1),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Attendance & Class'),
            Tab(text: 'Finance & Defaulters'),
            Tab(text: 'Teachers & Subjects'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Institute KPI Header Banner
                  if (_kpiSummary != null) _buildKpiBanner(_kpiSummary!),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search student, teacher, or class name...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 600,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAttendanceTab(),
                        _buildFinanceTab(),
                        _buildTeachersAndSubjectsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── KPI BANNER ──────────────────────────────────────────────────────────────
  Widget _buildKpiBanner(InstituteKpiSummary kpi) {
    return Card(
      color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceAround,
          children: [
            _kpiTile('Students', '${kpi.totalStudents}', Icons.school, Colors.blue),
            _kpiTile('Teachers', '${kpi.totalTeachers}', Icons.person, Colors.purple),
            _kpiTile('Classes', '${kpi.totalClasses}', Icons.class_, Colors.indigo),
            _kpiTile('Today Attendance', '${kpi.todayAttendanceRate.toStringAsFixed(0)}%', Icons.fact_check, Colors.green),
            _kpiTile('Pending Fees', '\$${kpi.totalPendingFees.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.red),
            _kpiTile('Pending Payroll', '\$${kpi.totalPendingPayroll.toStringAsFixed(0)}', Icons.payments, Colors.orange),
            _kpiTile('Monthly Rev', '\$${kpi.monthlyRevenue.toStringAsFixed(0)}', Icons.trending_up, Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _kpiTile(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 135,
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ── 1. ATTENDANCE & CLASS ANALYTICS TAB ────────────────────────────────────
  Widget _buildAttendanceTab() {
    final att = _attendanceSummary;

    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        // Filter Controls Row
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('classes').snapshots(),
                builder: (context, snapshot) {
                  final classes = snapshot.data?.docs ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Select Class',
                      prefixIcon: Icon(Icons.filter_alt_rounded),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Classes')),
                      ...classes.map((c) {
                        final data = c.data() as Map<String, dynamic>;
                        final name = data['name'] ?? c.id;
                        return DropdownMenuItem(value: c.id, child: Text(name));
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedClassId = val);
                      _loadAllAnalytics();
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _timeRangeLabel,
              items: ['Last 7 Days', 'Last 30 Days', 'All Time']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _timeRangeLabel = val);
                  _loadAllAnalytics();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Class Scoped Dashboard Summary (if selected)
        if (_classSummary != null)
          Card(
            color: Colors.blue.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Dashboard: ${_classSummary!.className}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _classKpi('Students', '${_classSummary!.totalStudents}'),
                      _classKpi('Attendance', '${_classSummary!.attendanceRate.toStringAsFixed(0)}%'),
                      _classKpi('Fees Paid', '\$${_classSummary!.feesCollected.toStringAsFixed(0)}'),
                      _classKpi('Pending Fees', '\$${_classSummary!.pendingFees.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Attendance Metric Card
        if (att != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${att.overallPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  Text('Overall Attendance Presence Rate',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('Present: ${att.presentCount}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text('Late: ${att.lateCount}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      Text('Absent: ${att.absentCount}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      Text('Excused: ${att.excusedCount}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),

        // Low Attendance Alert (< 75%)
        Text(
          'Low Attendance Warnings (< 75%)',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),

        if (att == null || att.lowAttendanceStudents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No students currently below 75% attendance.',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          )
        else
          ...att.lowAttendanceStudents
              .where((s) => _searchQuery.isEmpty || s.studentName.toLowerCase().contains(_searchQuery))
              .map((s) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                ),
                title: Text(s.studentName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text('Class: ${s.className} • ${s.presentCount}/${s.totalCount} Attended'),
                trailing: Text(
                  '${s.percentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red[700]),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _classKpi(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  // ── 2. FINANCIAL ANALYTICS & DEFAULTERS TAB ────────────────────────────────
  Widget _buildFinanceTab() {
    final defaulters = _feeDefaulters.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.studentName.toLowerCase().contains(_searchQuery) ||
          d.className.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        Text(
          'Student Fee Defaulters List',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),

        if (defaulters.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No fee defaulters found.', style: GoogleFonts.poppins(color: Colors.grey[600])),
          )
        else
          ...defaulters.map((d) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  child: const Icon(Icons.money_off_rounded, color: Colors.red),
                ),
                title: Text(d.studentName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text('Class: ${d.className} • ${d.studentEmail}'),
                trailing: Text(
                  '\$${d.pendingAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red[800]),
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── 3. TEACHERS & SUBJECTS TAB ─────────────────────────────────────────────
  Widget _buildTeachersAndSubjectsTab() {
    final teachers = _teacherSummaries.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.teacherName.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        Text(
          'Teacher Performance Leaderboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),

        if (teachers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No teacher performance records found.',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          )
        else
          ...teachers.map((t) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.teacherName,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Submission: ${t.submissionRate.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completed: ${t.completedLectures} Lecs • Cancellations: ${t.cancellationsCount} • Avg Class Attendance: ${t.avgClassAttendance.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 20),
        Text(
          'Subject Performance Breakdown',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),

        if (_subjectSummaries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No subject analytics records found.',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          )
        else
          ..._subjectSummaries.map((sub) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(sub.subjectName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text('Teacher: ${sub.teacherName} • ${sub.lecturesCount} Lectures'),
                trailing: Text(
                  '${sub.attendanceRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── CSV EXPORT MODAL DIALOG ────────────────────────────────────────────────
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Export CSV Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fact_check_rounded, color: Colors.green),
              title: const Text('Export Attendance CSV'),
              onTap: () {
                Navigator.pop(ctx);
                if (_attendanceSummary != null) {
                  final csv = _reportService.exportAttendanceCsv(_attendanceSummary!);
                  _showCsvPreview('Attendance_Report.csv', csv);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_rounded, color: Colors.purple),
              title: const Text('Export Teacher Performance CSV'),
              onTap: () {
                Navigator.pop(ctx);
                final csv = _reportService.exportTeacherPerformanceCsv(_teacherSummaries);
                _showCsvPreview('Teacher_Performance_Report.csv', csv);
              },
            ),
            ListTile(
              leading: const Icon(Icons.money_off_rounded, color: Colors.red),
              title: const Text('Export Fee Defaulters CSV'),
              onTap: () {
                Navigator.pop(ctx);
                final csv = _reportService.exportFeeDefaultersCsv(_feeDefaulters);
                _showCsvPreview('Fee_Defaulters_Report.csv', csv);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCsvPreview(String fileName, String csvContent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(fileName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              csvContent,
              style: GoogleFonts.firaCode(fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
