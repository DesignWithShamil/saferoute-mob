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
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brand, AppColors.brandDeep],
              ),
            ),
            child: Text(
              student.fullName.isNotEmpty ? student.fullName.characters.first.toUpperCase() : '?',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (age != null) 'Age $age',
                    if (student.classLabel.isNotEmpty) 'Class ${student.classLabel}',
                    if (student.admissionNumber.isNotEmpty) student.admissionNumber,
                    if (student.status.isNotEmpty) student.status,
                  ].join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
                ),
                if (student.bloodGroup != null && student.bloodGroup!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: StatusChip(label: 'Blood group ${student.bloodGroup}', color: AppColors.red),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
            const Text('No linked parents on file.', style: TextStyle(fontSize: 14, color: AppColors.slate))
          else
            for (final p in rows)
              _ContactTile(
                icon: Icons.person_outline,
                color: AppColors.brand,
                title: p.fullName.isEmpty ? 'Parent' : p.fullName,
                subtitle: [
                  if (p.relation.isNotEmpty) p.relation[0].toUpperCase() + p.relation.substring(1).toLowerCase(),
                  if (p.phone.isNotEmpty) p.phone,
                  if (p.email.isNotEmpty) p.email,
                ].join(' · '),
              ),
          if (student.emergencyContactPhone.isNotEmpty || student.emergencyContactName.isNotEmpty) ...[
            _ContactTile(
              icon: Icons.emergency_outlined,
              color: AppColors.red,
              title: student.emergencyContactName.isEmpty ? 'Emergency contact' : student.emergencyContactName,
              subtitle: student.emergencyContactPhone,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.icon, required this.color, required this.title, required this.subtitle});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
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
            const Text('Route stops', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: AppColors.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.35)),
                ],
              ),
            ),
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
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: s.publicId == highlightStopId ? AppColors.brand.withValues(alpha: 0.08) : AppColors.slate.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: s.publicId == highlightStopId ? AppColors.brand.withValues(alpha: 0.35) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: s.publicId == highlightStopId ? AppColors.brand : AppColors.slate.withValues(alpha: 0.15),
                  child: Text('${s.sequence}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.publicId == highlightStopId ? Colors.white : AppColors.slate)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: AppColors.ink, fontWeight: s.publicId == highlightStopId ? FontWeight.w800 : FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
