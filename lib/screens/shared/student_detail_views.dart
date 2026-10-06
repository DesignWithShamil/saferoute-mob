import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/student.dart';
import '../../models/transport.dart';
import '../../widgets/state_views.dart';

class StudentHeaderCard extends StatelessWidget {
  const StudentHeaderCard({super.key, required this.student, this.trailing});

  final Student student;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final age = student.ageYears;
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            child: Text(
              student.fullName.isNotEmpty ? student.fullName.characters.first.toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  [
                    if (age != null) 'Age $age',
                    if (student.classLabel.isNotEmpty) 'Class ${student.classLabel}',
                    if (student.admissionNumber.isNotEmpty) student.admissionNumber,
                    if (student.status.isNotEmpty) student.status,
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.slate, height: 1.35),
                ),
                if (student.bloodGroup != null && student.bloodGroup!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: StatusChip(label: 'Blood group ${student.bloodGroup}', color: AppColors.red),
                  ),
              ],
            ),
          ),
          trailing?,
        ],
      ),
    );
  }
}

class ParentsSection extends StatelessWidget {
  const ParentsSection({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final rows = student.parents.isNotEmpty
        ? student.parents
        : [
            if (student.primaryParent != null)
              StudentParentLink(
                fullName: student.primaryParent!.fullName,
                phone: student.primaryParent!.phone,
                email: student.primaryParent!.email,
                relation: 'Primary contact',
              ),
          ];
    if (rows.isEmpty &&
        student.emergencyContactName.isEmpty &&
        student.emergencyContactPhone.isEmpty) {
      return const SizedBox.shrink();
    }
    return SectionCard(
      title: 'Parents & emergency',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            const Text('No linked parents on file.')
          else
            for (final p in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(p.fullName.isEmpty ? 'Parent' : p.fullName),
                subtitle: Text([
                  if (p.relation.isNotEmpty) p.relation.toUpperCase(),
                  if (p.phone.isNotEmpty) p.phone,
                  if (p.email.isNotEmpty) p.email,
                ].join(' · ')),
              ),
          if (student.emergencyContactPhone.isNotEmpty || student.emergencyContactName.isNotEmpty) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emergency_outlined, color: AppColors.red),
              title: Text(student.emergencyContactName.isEmpty ? 'Emergency contact' : student.emergencyContactName),
              subtitle: Text(student.emergencyContactPhone),
            ),
          ],
        ],
      ),
    );
  }
}

class TransportLegSection extends StatelessWidget {
  const TransportLegSection({
    super.key,
    required this.title,
    required this.icon,
    required this.bus,
    required this.stop,
    this.routeName,
    this.routeStops,
    this.crewDriver,
    this.crewHelper,
  });

  final String title;
  final IconData icon;
  final BusRef? bus;
  final StopRef? stop;
  final String? routeName;
  final List<StopRef>? routeStops;
  final PersonRef? crewDriver;
  final PersonRef? crewHelper;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(icon, 'Bus', bus == null ? 'Not assigned' : _busLine(bus!)),
          _infoRow(Icons.place_outlined, 'Stop', _stopLine(stop)),
          if (routeName != null && routeName!.isNotEmpty) _infoRow(Icons.route_outlined, 'Route', routeName!),
          if (crewDriver != null && crewDriver!.fullName.isNotEmpty)
            _infoRow(Icons.drive_eta_outlined, 'Driver', '${crewDriver!.fullName}${crewDriver!.phone.isNotEmpty ? ' · ${crewDriver!.phone}' : ''}'),
          if (crewHelper != null && crewHelper!.fullName.isNotEmpty)
            _infoRow(Icons.support_agent_outlined, 'Helper', '${crewHelper!.fullName}${crewHelper!.phone.isNotEmpty ? ' · ${crewHelper!.phone}' : ''}'),
          if (routeStops != null && routeStops!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Route stops', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            RouteStopsList(stops: routeStops!, highlightStopId: stop?.publicId),
          ],
        ],
      ),
    );
  }

  static String _busLine(BusRef bus) {
    if (bus.registrationNumber.isNotEmpty) return '${bus.busNumber} · Plate ${bus.registrationNumber}';
    return bus.busNumber;
  }

  static String _stopLine(StopRef? stop) {
    if (stop == null) return 'Not assigned';
    final time = stop.pickupTime ?? stop.dropTime;
    final timeStr = time != null && time.isNotEmpty ? ' · ${_formatTime(time)}' : '';
    final addr = stop.address.isNotEmpty ? '\n${stop.address}' : '';
    return '${stop.name}$timeStr$addr';
  }

  static String _formatTime(String hhmmss) {
    final parts = hhmmss.split(':');
    if (parts.length < 2) return hhmmss;
    final dt = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return DateFormat.jm().format(dt);
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(child: Text('$label\n$value', style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}

class RouteStopsList extends StatelessWidget {
  const RouteStopsList({super.key, required this.stops, this.highlightStopId});

  final List<StopRef> stops;
  final String? highlightStopId;

  @override
  Widget build(BuildContext context) {
    final sorted = [...stops]..sort((a, b) => a.sequence.compareTo(b.sequence));
    return Column(
      children: [
        for (final s in sorted)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: s.publicId == highlightStopId ? AppColors.brand.withValues(alpha: 0.08) : AppColors.slate.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: s.publicId == highlightStopId ? AppColors.brand.withValues(alpha: 0.35) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: s.publicId == highlightStopId ? AppColors.brand : AppColors.slate.withValues(alpha: 0.15),
                  child: Text('${s.sequence}', style: TextStyle(fontSize: 12, color: s.publicId == highlightStopId ? Colors.white : AppColors.slate)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.name,
                    style: TextStyle(fontWeight: s.publicId == highlightStopId ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
