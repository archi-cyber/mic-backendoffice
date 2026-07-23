// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/localization/app_localizations.dart';
import '../utils/member_utils.dart';

/// Thresholds for diligence (present / scheduled services in month).
const double kDiligenceDiligentMin = 0.8;
const double kDiligenceModerateMin = 0.5;

/// One church service slot in a month (date + church_service_id + name).
class _ServiceSlot {
  _ServiceSlot({
    required this.serviceDate,
    required this.churchServiceId,
    required this.serviceName,
    required this.records,
    required this.visitors,
  });

  final DateTime serviceDate;
  final String churchServiceId;
  final String serviceName;
  final List<Map<String, dynamic>> records;
  final List<Map<String, dynamic>> visitors;

  String get columnKey =>
      '${serviceDate.toIso8601String().split('T')[0]}|$churchServiceId';

  String shortHeader(AppLocalizations l10n) {
    final d = DateFormat.yMMMd(l10n.locale.toString()).format(serviceDate);
    return '$serviceName — $d';
  }
}

/// Builds PDF widgets for church attendance grouped by calendar month.
class ChurchAttendanceReportBuilder {
  static List<pw.Widget> buildMonthlySections(
    List<Map<String, dynamic>> detailedServices, {
    required List<Map<String, dynamic>> allMembers,
    required AppLocalizations localizations,
  }) {
    if (detailedServices.isEmpty) return [];

    final byMonth = <String, List<Map<String, dynamic>>>{};
    for (final s in detailedServices) {
      final d = DateTime.parse(s['service_date'] as String);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(s);
    }

    final sortedKeys = byMonth.keys.toList()..sort();
    final out = <pw.Widget>[];

    for (final key in sortedKeys) {
      final list = byMonth[key]!;
      list.sort((a, b) {
        final da = DateTime.parse(a['service_date'] as String);
        final db = DateTime.parse(b['service_date'] as String);
        final c = da.compareTo(db);
        if (c != 0) return c;
        final na = (a['name'] ?? '').toString().toLowerCase();
        final nb = (b['name'] ?? '').toString().toLowerCase();
        return na.compareTo(nb);
      });

      final slots = list
          .map(
            (s) => _ServiceSlot(
              serviceDate: DateTime.parse(s['service_date'] as String),
              churchServiceId: s['id']?.toString() ?? '',
              serviceName: s['name']?.toString() ?? 'Church service',
              records: List<Map<String, dynamic>>.from(
                s['attendance'] as List<Map<String, dynamic>>? ?? [],
              ),
              visitors: List<Map<String, dynamic>>.from(
                s['visitors'] as List<Map<String, dynamic>>? ?? [],
              ),
            ),
          )
          .toList();

      out.addAll(_buildOneMonth(
        key,
        slots,
        allMembers,
        localizations,
      ));
    }

    return out;
  }

  static List<pw.Widget> _buildOneMonth(
    String yyyymm,
    List<_ServiceSlot> slots,
    List<Map<String, dynamic>> allMembers,
    AppLocalizations l10n,
  ) {
    final parts = yyyymm.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final monthDate = DateTime(y, m);
    final monthTitle =
        DateFormat.yMMMM(l10n.locale.toString()).format(monthDate);

    if (slots.isEmpty) {
      return [
        pw.Text(
          monthTitle,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ];
    }

    int presentCountForSlot(_ServiceSlot s) {
      final membersPresent = s.records.where((r) {
        final t = r['attendance_type']?.toString();
        return t == 'onsite' || t == 'online';
      }).length;
      final visitorsPresent = s.visitors.where((v) {
        final t = v['attendance_type']?.toString();
        return t == 'onsite' || t == 'online';
      }).length;
      return membersPresent + visitorsPresent;
    }

    final slotsByServiceName = <String, List<_ServiceSlot>>{};
    for (final slot in slots) {
      slotsByServiceName.putIfAbsent(slot.serviceName, () => []).add(slot);
    }
    for (final group in slotsByServiceName.values) {
      group.sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
    }
    final sortedServiceNames = slotsByServiceName.keys.toList()..sort();

    // memberId -> attendance status per slot: onsite / online / absent
    final memberStatusBySlot = <String, Map<String, String>>{};
    final onsite = <String, int>{};
    final online = <String, int>{};

    for (final slot in slots) {
      for (final r in slot.records) {
        final id = r['member_id']?.toString();
        if (id == null) continue;

        final at = r['attendance_type']?.toString() ?? 'absent';
        String mark;
        if (at == 'onsite') {
          mark = 'onsite';
          onsite[id] = (onsite[id] ?? 0) + 1;
        } else if (at == 'online') {
          mark = 'online';
          online[id] = (online[id] ?? 0) + 1;
        } else {
          mark = 'absent';
        }
        memberStatusBySlot.putIfAbsent(id, () => {})[slot.columnKey] = mark;
      }
    }

    final memberRows = <Map<String, dynamic>>[];
    for (final raw in allMembers) {
      final id = raw['id']?.toString();
      if (id == null) continue;
      memberRows.add(raw);
    }
    memberRows.sort((a, b) {
      final fa = (a['first_name'] ?? '').toString().toLowerCase();
      final fb = (b['first_name'] ?? '').toString().toLowerCase();
      final la = (a['last_name'] ?? '').toString().toLowerCase();
      final lb = (b['last_name'] ?? '').toString().toLowerCase();
      final c = la.compareTo(lb);
      if (c != 0) return c;
      return fa.compareTo(fb);
    });

    final memberIds =
        memberRows.map((e) => e['id'].toString()).toList(growable: false);
    final memberNames = <String, String>{};
    for (final row in memberRows) {
      final id = row['id'].toString();
      final fn = row['first_name']?.toString() ?? '';
      final ln = row['last_name']?.toString() ?? '';
      var name = ('$fn $ln').trim().isEmpty ? id : ('$fn $ln').trim();

      final birthday = row['birthday'];
      DateTime? birthdayDate;
      if (birthday is String) {
        try {
          birthdayDate = DateTime.parse(birthday.split('T').first);
        } catch (_) {}
      } else if (birthday is DateTime) {
        birthdayDate = birthday;
      }
      final tags = <String>[];
      if (MemberUtils.getAgeCategory(birthdayDate) == 'child') {
        tags.add(l10n.attendanceReportChildTag);
      }
      if (row['is_new_comer'] == true) {
        tags.add(l10n.attendanceReportNewComerTag);
      }
      if (tags.isNotEmpty) {
        name = '$name (${tags.join(', ')})';
      }

      memberNames[id] = name;
    }

    final visitorRows = <Map<String, dynamic>>[];
    final seenVisitorIds = <String>{};
    for (final slot in slots) {
      for (final visitor in slot.visitors) {
        final id = visitor['id']?.toString();
        if (id == null || !seenVisitorIds.add(id)) continue;
        visitorRows.add(visitor);
      }
    }
    visitorRows.sort((a, b) {
      final la = (a['last_name'] ?? '').toString().toLowerCase();
      final lb = (b['last_name'] ?? '').toString().toLowerCase();
      final c = la.compareTo(lb);
      if (c != 0) return c;
      final fa = (a['first_name'] ?? '').toString().toLowerCase();
      final fb = (b['first_name'] ?? '').toString().toLowerCase();
      return fa.compareTo(fb);
    });

    final visitorIds =
        visitorRows.map((e) => 'visitor_${e['id']}').toList(growable: false);
    final visitorNames = <String, String>{};
    for (final row in visitorRows) {
      final id = 'visitor_${row['id']}';
      final fn = row['first_name']?.toString() ?? '';
      final ln = row['last_name']?.toString() ?? '';
      final name = ('$fn $ln').trim();
      visitorNames[id] = name.isEmpty ? id : name;
    }

    final nScheduled = slots.length;
    final pctDiligent = (kDiligenceDiligentMin * 100).round();
    final pctModerate = (kDiligenceModerateMin * 100).round();

    final memberSpecificObservations = <String, String>{};
    for (final id in memberIds) {
      final joined = _joinedMemberSpecificObservations(id, slots, l10n);
      if (joined.isNotEmpty) {
        memberSpecificObservations[id] = joined;
      }
    }

    return [
      pw.Text(
        monthTitle,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        l10n.churchAttendanceReportPdfIntro,
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        l10n.churchAttendanceReportPdfDiligenceNote(pctDiligent, pctModerate),
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 12),
      _memberTable(
        l10n: l10n,
        slots: slots,
        memberIds: memberIds,
        memberNames: memberNames,
        memberStatusBySlot: memberStatusBySlot,
        memberSpecificObservations: memberSpecificObservations,
        visitorIds: visitorIds,
        visitorNames: visitorNames,
        onsite: onsite,
        online: online,
        nScheduled: nScheduled,
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        l10n.attendanceReportPresenceChartsSection,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      ...() {
        const chartColors = [
          PdfColors.green,
          PdfColors.orange,
          PdfColors.purple,
          PdfColors.teal,
          PdfColors.indigo,
        ];
        final chartWidgets = <pw.Widget>[];
        for (var i = 0; i < sortedServiceNames.length; i++) {
          final name = sortedServiceNames[i];
          final group = slotsByServiceName[name]!;
          chartWidgets.add(
            _presenceLineChart(
              chartTitle: '$name — ${l10n.attendanceReportPresenceChartsSection}',
              xLabels: group.map((s) => s.shortHeader(l10n)).toList(),
              values: group.map(presentCountForSlot).toList(),
              lineAndMarkerColor: chartColors[i % chartColors.length],
              l10n: l10n,
            ),
          );
          chartWidgets.add(pw.SizedBox(height: 12));
        }
        chartWidgets.add(
          _presenceLineChart(
            chartTitle: l10n.attendanceReportTotalMonthlyPresenceChart,
            xLabels: slots.map((s) => s.shortHeader(l10n)).toList(),
            values: slots.map(presentCountForSlot).toList(),
            lineAndMarkerColor: PdfColors.blue,
            l10n: l10n,
          ),
        );
        chartWidgets.add(pw.SizedBox(height: 12));
        return chartWidgets;
      }(),
      pw.SizedBox(height: 24),
    ];
  }

  /// Line chart: one point per service in the month; y = present count.
  static pw.Widget _presenceLineChart({
    required String chartTitle,
    required List<String> xLabels,
    required List<int> values,
    required PdfColor lineAndMarkerColor,
    required AppLocalizations l10n,
  }) {
    assert(xLabels.length == values.length);

    if (values.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              chartTitle,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: lineAndMarkerColor,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              l10n.attendanceReportChartNoData,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
        ),
      );
    }

    final maxV = math.max(1, values.reduce(math.max));

    const chartW = 480.0;
    const chartH = 100.0;
    const padL = 10.0;
    const padR = 10.0;
    const padB = 8.0;
    const padT = 10.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            chartTitle,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: lineAndMarkerColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.CustomPaint(
            size: const PdfPoint(chartW, chartH),
            painter: (canvas, size) {
              final w = size.x;
              final h = size.y;
              final plotW = w - padL - padR;
              final plotH = h - padB - padT;
              final baseY = padB;
              final topY = padB + plotH;

              double xFor(int i) {
                if (values.length <= 1) return padL + plotW / 2;
                return padL + plotW * i / (values.length - 1);
              }

              double yForNum(num v) =>
                  baseY + (v / maxV) * (topY - baseY);

              // Horizontal grid
              canvas
                ..setStrokeColor(PdfColors.grey300)
                ..setLineWidth(0.4);
              for (var g = 0; g <= 4; g++) {
                final gy = baseY + (g / 4) * (topY - baseY);
                canvas.drawLine(padL, gy, padL + plotW, gy);
              }
              canvas.strokePath();

              // Line through points
              canvas
                ..setStrokeColor(lineAndMarkerColor)
                ..setLineWidth(2)
                ..setLineCap(PdfLineCap.round)
                ..setLineJoin(PdfLineJoin.round)
                ..moveTo(xFor(0), yForNum(values[0]));
              for (var i = 1; i < values.length; i++) {
                canvas.lineTo(xFor(i), yForNum(values[i]));
              }
              canvas.strokePath();

              // Markers
              for (var i = 0; i < values.length; i++) {
                canvas
                  ..setFillColor(lineAndMarkerColor)
                  ..drawEllipse(xFor(i), yForNum(values[i]), 4, 4)
                  ..fillPath();
              }
            },
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: pw.WrapAlignment.start,
            children: List.generate(values.length, (i) {
              return pw.SizedBox(
                width: 72,
                child: pw.Column(
                  children: [
                    pw.Text(
                      '${values[i]}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: lineAndMarkerColor,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      xLabels[i],
                      style: const pw.TextStyle(fontSize: 6),
                      textAlign: pw.TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static String _observationLabel(AppLocalizations l10n, double rate) {
    if (rate >= kDiligenceDiligentMin) return l10n.attendanceReportDiligent;
    if (rate >= kDiligenceModerateMin) {
      return l10n.attendanceReportModeratelyDiligent;
    }
    return l10n.attendanceReportNotDiligent;
  }

  static bool _visitorMatchesSlot(
    Map<String, dynamic> visitor,
    _ServiceSlot slot,
  ) {
    final visitDateRaw = visitor['visit_date']?.toString();
    if (visitDateRaw == null) return false;
    final visitDate = DateTime.parse(visitDateRaw.split('T').first);
    if (visitDate.year != slot.serviceDate.year ||
        visitDate.month != slot.serviceDate.month ||
        visitDate.day != slot.serviceDate.day) {
      return false;
    }
    final churchServiceId = visitor['church_service_id']?.toString();
    if (churchServiceId != null &&
        churchServiceId.isNotEmpty &&
        churchServiceId != slot.churchServiceId) {
      return false;
    }
    return true;
  }

  static bool _visitorAttendedSlot(
    Map<String, dynamic> visitor,
    _ServiceSlot slot,
  ) {
    if (!_visitorMatchesSlot(visitor, slot)) return false;
    final attendanceType = visitor['attendance_type']?.toString();
    return attendanceType == 'onsite' || attendanceType == 'online';
  }

  static String _visitorSlotLabel(
    AppLocalizations l10n,
    Map<String, dynamic> visitor,
    _ServiceSlot slot,
  ) {
    if (!_visitorMatchesSlot(visitor, slot)) return '';
    final attendanceType = visitor['attendance_type']?.toString() ?? 'absent';
    return _attendanceStatusLabel(l10n, attendanceType);
  }

  static Map<String, dynamic>? _visitorForSlot(
    _ServiceSlot slot,
    String visitorRowId,
  ) {
    for (final v in slot.visitors) {
      if ('visitor_${v['id']}' == visitorRowId) return v;
    }
    return null;
  }

  static String _joinedMemberSpecificObservations(
    String memberId,
    List<_ServiceSlot> slots,
    AppLocalizations l10n,
  ) {
    final parts = <String>[];
    for (final slot in slots) {
      for (final record in slot.records) {
        if (record['member_id']?.toString() != memberId) continue;
        final observation = record['specific_observation']?.toString().trim();
        if (observation == null || observation.isEmpty) continue;
        parts.add('${slot.shortHeader(l10n)}: $observation');
        break;
      }
    }
    return parts.join('; ');
  }

  static pw.Widget _memberTable({
    required AppLocalizations l10n,
    required List<_ServiceSlot> slots,
    required List<String> memberIds,
    required Map<String, String> memberNames,
    required Map<String, Map<String, String>> memberStatusBySlot,
    required Map<String, String> memberSpecificObservations,
    required List<String> visitorIds,
    required Map<String, String> visitorNames,
    required Map<String, int> onsite,
    required Map<String, int> online,
    required int nScheduled,
  }) {
    final baseStyle = pw.TextStyle(fontSize: 6);
    final headerStyle =
        pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold);

    pw.Widget cell(
      String t, {
      pw.TextStyle? style,
      pw.Alignment align = pw.Alignment.centerLeft,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Align(
          alignment: align,
          child: pw.Text(t, style: style ?? baseStyle),
        ),
      );
    }

    final headerRow1 = <pw.Widget>[
      cell(l10n.attendanceReportFullName, style: headerStyle),
      cell(l10n.attendanceReportOnsiteTotal,
          style: headerStyle, align: pw.Alignment.center),
      cell(l10n.attendanceReportOnlineTotal,
          style: headerStyle, align: pw.Alignment.center),
      cell(l10n.attendanceReportTotalPresent,
          style: headerStyle, align: pw.Alignment.center),
      cell(l10n.attendanceReportObservation, style: headerStyle),
      cell(l10n.attendanceReportSpecificObservations, style: headerStyle),
    ];
    for (final s in slots) {
      headerRow1.add(
        cell(
          s.shortHeader(l10n),
          style: headerStyle,
          align: pw.Alignment.center,
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(children: headerRow1),
    ];

    for (final id in memberIds) {
      final on = onsite[id] ?? 0;
      final off = online[id] ?? 0;
      final tot = on + off;
      final rate = nScheduled > 0 ? tot / nScheduled : 0.0;
      final obs = _observationLabel(l10n, rate);

      final statusMap = memberStatusBySlot[id] ?? {};
      final dataCells = <pw.Widget>[
        cell(memberNames[id] ?? id),
        cell('$on', align: pw.Alignment.center),
        cell('$off', align: pw.Alignment.center),
        cell('$tot', align: pw.Alignment.center),
        cell(obs),
        cell(memberSpecificObservations[id] ?? ''),
      ];

      for (final s in slots) {
        final mark = statusMap[s.columnKey];
        // No row in DB for this member + service => treat as absent
        final effective = mark ?? 'absent';
        dataCells.add(
          cell(
            _attendanceStatusLabel(l10n, effective),
            align: pw.Alignment.center,
          ),
        );
      }

      rows.add(pw.TableRow(children: dataCells));
    }

    if (visitorIds.isNotEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            cell(
              l10n.attendanceReportVisitorsSection,
              style: headerStyle,
            ),
            for (var i = 0; i < 5 + slots.length; i++) cell(''),
          ],
        ),
      );
    }

    for (final id in visitorIds) {
      var visitCount = 0;
      final dataCells = <pw.Widget>[
        cell('${visitorNames[id] ?? id} (${l10n.attendanceReportVisitor})'),
        cell('-', align: pw.Alignment.center),
        cell('-', align: pw.Alignment.center),
        cell('-', align: pw.Alignment.center),
        cell(l10n.attendanceReportVisitor),
        cell(''),
      ];

      for (final s in slots) {
        final visitor = _visitorForSlot(s, id);
        if (visitor != null && _visitorAttendedSlot(visitor, s)) {
          visitCount++;
        }
        dataCells.add(
          cell(
            visitor == null ? '' : _visitorSlotLabel(l10n, visitor, s),
            align: pw.Alignment.center,
          ),
        );
      }

      if (visitCount > 0) {
        dataCells[3] = cell('$visitCount', align: pw.Alignment.center);
      }

      rows.add(pw.TableRow(children: dataCells));
    }

    final totalCols = 6 + slots.length;
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.6),
      1: const pw.FlexColumnWidth(0.45),
      2: const pw.FlexColumnWidth(0.45),
      3: const pw.FlexColumnWidth(0.5),
      4: const pw.FlexColumnWidth(1.0),
      5: const pw.FlexColumnWidth(1.1),
    };
    for (var c = 6; c < totalCols; c++) {
      columnWidths[c] = const pw.FlexColumnWidth(0.55);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static String _attendanceStatusLabel(
    AppLocalizations l10n,
    String status,
  ) {
    switch (status) {
      case 'onsite':
        return l10n.attendanceReportOnsite;
      case 'online':
        return l10n.attendanceReportOnline;
      case 'absent':
        return l10n.attendanceReportAbsent;
      default:
        return l10n.attendanceReportAbsent;
    }
  }
}
