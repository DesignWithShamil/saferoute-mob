import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/storage/token_storage.dart';
import '../../widgets/ethiyo_brand.dart';
import '../../widgets/state_views.dart';

enum TutorialRole {
  parent,
  driver,
  helper,
}

class TutorialStep {
  const TutorialStep({
    required this.tag,
    required this.title,
    required this.description,
    required this.highlight,
    required this.icon,
    required this.accentColor,
  });

  final String tag;
  final String title;
  final String description;
  final String highlight;
  final IconData icon;
  final Color accentColor;
}

class UserTutorialScreen extends StatefulWidget {
  const UserTutorialScreen({
    super.key,
    required this.onFinished,
    this.userId,
    this.initialRole = TutorialRole.parent,
    this.isStandalone = false,
    this.lockRole = false,
  });

  final VoidCallback onFinished;
  final String? userId;
  final TutorialRole initialRole;
  final bool isStandalone;
  final bool lockRole;

  @override
  State<UserTutorialScreen> createState() => _UserTutorialScreenState();
}

class _UserTutorialScreenState extends State<UserTutorialScreen> {
  late TutorialRole _selectedRole;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onRoleChanged(TutorialRole role) {
    if (_selectedRole == role) return;
    setState(() {
      _selectedRole = role;
      _currentPage = 0;
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _completeTutorial() async {
    final storage = TokenStorage();
    await storage.markUserTutorialSeen(widget.userId);
    if (!mounted) return;
    widget.onFinished();
  }

  List<TutorialStep> get _currentSteps {
    switch (_selectedRole) {
      case TutorialRole.parent:
        return const [
          TutorialStep(
            tag: 'Child Profile',
            title: 'View & Manage Children\'s Profiles',
            description:
                'Access your child\'s complete school profile, admission details, blood group, emergency contact numbers, assigned bus info, and medical notes in one tap.',
            highlight: 'Keep emergency details and school contact information readily accessible.',
            icon: Icons.badge_rounded,
            accentColor: Color(0xFF1585E8),
          ),
          TutorialStep(
            tag: 'Live Bus Tracking',
            title: 'Track School Bus Live on Map',
            description:
                'See the exact real-time GPS location of your child\'s school bus as it travels along the route. Check live bus speed and traffic updates as it approaches your stop.',
            highlight: 'Live GPS location streamed directly to your screen with sub-minute updates.',
            icon: Icons.location_on_rounded,
            accentColor: Color(0xFF0284C7),
          ),
          TutorialStep(
            tag: 'Bus Location & Route',
            title: 'View Bus Location, Route & ETAs',
            description:
                'View morning and evening sequential route stops plotted on the interactive map with estimated arrival times (ETA) so you never wait unnecessarily in the rain or heat.',
            highlight: 'Accurate ETA calculations keep you ahead of scheduled bus stops.',
            icon: Icons.alt_route_rounded,
            accentColor: Color(0xFF6366F1),
          ),
          TutorialStep(
            tag: 'Pickup & Drop Attendance',
            title: 'Check Pickup & Drop-Off Attendance',
            description:
                'Review verified attendance records. SafeRoute logs exact timestamps when your child boards the bus in the morning and safely steps down at the school or home stop.',
            highlight: 'Verified timestamped records for morning pickup and afternoon drop-off.',
            icon: Icons.fact_check_rounded,
            accentColor: Color(0xFF10B981),
          ),
          TutorialStep(
            tag: 'Student Security PIN',
            title: 'Student Security PIN & Verification',
            description:
                'Every student is protected with a unique security PIN and digital transit token for safe handover. Drivers and helpers cross-verify this PIN before release.',
            highlight: 'Secure PIN ensures your child is only handed over to authorized guardians.',
            icon: Icons.pin_rounded,
            accentColor: Color(0xFF8B5CF6),
          ),
          TutorialStep(
            tag: 'Smart Notifications',
            title: 'Instant Push Alerts & Notifications',
            description:
                'Receive immediate push notifications when the bus starts its trip, reaches nearby stops, when your child safely boards or alights, or if a delay is reported.',
            highlight: 'Instant notifications keep you informed without needing to watch the map.',
            icon: Icons.notifications_active_rounded,
            accentColor: Color(0xFFF59E0B),
          ),
          TutorialStep(
            tag: 'Multi-Child Management',
            title: 'Seamlessly Manage Multiple Children',
            description:
                'Have multiple children registered with SafeRoute? Switch between their profiles with one tap from the top bar to track different buses, classes, and schedules.',
            highlight: 'Easily switch and monitor each child\'s bus and route independently.',
            icon: Icons.family_restroom_rounded,
            accentColor: Color(0xFFEC4899),
          ),
          TutorialStep(
            tag: 'Leaves & Parent Services',
            title: 'One-Tap Leave Requests & Services',
            description:
                'If your child is unwell or staying home, submit a leave request with one tap. This alerts the driver instantly so the bus will not wait at your stop.',
            highlight: 'One-tap leave application prevents unnecessary bus stops and delays.',
            icon: Icons.event_busy_rounded,
            accentColor: Color(0xFF14B8A6),
          ),
        ];

      case TutorialRole.driver:
        return const [
          TutorialStep(
            tag: 'Driver Dashboard',
            title: 'Driver Operational Dashboard',
            description:
                'Your central operational hub provides a crystal-clear overview of today\'s scheduled trips, assigned vehicle, route details, and total student counts at a glance.',
            highlight: 'Your complete daily operations and trip schedule in one unified view.',
            icon: Icons.dashboard_rounded,
            accentColor: Color(0xFF1585E8),
          ),
          TutorialStep(
            tag: 'Buses & Routes',
            title: 'View Assigned Buses & Routes',
            description:
                'Inspect your assigned bus registration details, sequential morning and evening stops plotted on the interactive route map, and scheduled timing for each stop.',
            highlight: 'Sequential stop-by-stop route breakdown with student pickup numbers.',
            icon: Icons.directions_bus_rounded,
            accentColor: Color(0xFF0284C7),
          ),
          TutorialStep(
            tag: 'Trip Start & End',
            title: 'Start & End Route Trips with One Tap',
            description:
                'Tap "Start Trip" when commencing your morning or afternoon route. When all stops are completed and students have alighted, tap "End Trip" to conclude.',
            highlight: 'Simple one-touch workflow to start and close daily bus routes.',
            icon: Icons.play_circle_fill_rounded,
            accentColor: Color(0xFF10B981),
          ),
          TutorialStep(
            tag: 'Live GPS Tracking',
            title: 'Continuous Background GPS Tracking',
            description:
                'During active trips, SafeRoute automatically streams high-accuracy GPS coordinates in the background, allowing waiting parents and school dispatch to track your live position.',
            highlight: 'Battery-efficient background GPS tracking operates seamlessly while driving.',
            icon: Icons.my_location_rounded,
            accentColor: Color(0xFF6366F1),
          ),
          TutorialStep(
            tag: 'Mark Student Boarding',
            title: 'Mark Student Boarding at Each Stop',
            description:
                'At every pickup stop, easily mark students as they board the bus. SafeRoute immediately sends push alerts to parents confirming their child is safely on board.',
            highlight: 'Instant boarding confirmation keeps parents and school dispatch in sync.',
            icon: Icons.person_add_alt_1_rounded,
            accentColor: Color(0xFF14B8A6),
          ),
          TutorialStep(
            tag: 'Mark Student Dropping',
            title: 'Mark Student Dropping at School & Stops',
            description:
                'When arriving at the school campus or student drop stops, mark alighting students to complete their transit record and notify parents immediately.',
            highlight: 'Ensures every student is accounted for when alighting from the bus.',
            icon: Icons.person_remove_rounded,
            accentColor: Color(0xFFF59E0B),
          ),
          TutorialStep(
            tag: 'Attendance & PIN',
            title: 'Student Attendance & Security PIN',
            description:
                'Verify student attendance and use the student security PIN when handing over young students to authorized guardians at afternoon drop-off.',
            highlight: 'PIN verification guarantees authorized and safe child handovers.',
            icon: Icons.verified_user_rounded,
            accentColor: Color(0xFF8B5CF6),
          ),
          TutorialStep(
            tag: 'Emergency SOS',
            title: 'SOS Distress & Emergency Broadcast',
            description:
                'In critical road incidents, breakdowns, or medical emergencies, hold the SOS button to instantly alert school dispatch and broadcast rapid distress warnings.',
            highlight: 'Immediate multi-channel emergency broadcast direct to authorities.',
            icon: Icons.emergency_rounded,
            accentColor: Color(0xFFEF4444),
          ),
          TutorialStep(
            tag: 'Notifications & Alerts',
            title: 'Route Notifications & Delay Reports',
            description:
                'Stay updated with immediate notifications when parents apply for leave so you skip unnecessary stops, and broadcast 5 or 10-minute traffic delay notices in one tap.',
            highlight: 'Real-time leave updates prevent waiting at empty stops.',
            icon: Icons.notifications_active_rounded,
            accentColor: Color(0xFF0284C7),
          ),
        ];

      case TutorialRole.helper:
        return const [
          TutorialStep(
            tag: 'Helper Dashboard',
            title: 'Helper Operational Dashboard',
            description:
                'Your operational dashboard displays today\'s bus assignment, driver partner details, morning and evening route schedule, and total assigned students.',
            highlight: 'Daily overview tailored for student safety and stop management.',
            icon: Icons.shield_rounded,
            accentColor: Color(0xFF1585E8),
          ),
          TutorialStep(
            tag: 'Assigned Routes',
            title: 'Review Assigned Routes & Stops',
            description:
                'Inspect route schedules, sequential stops, and estimated arrival times so you can prepare students for orderly boarding and alighting.',
            highlight: 'Sequential stop sequence with expected timings and student counts.',
            icon: Icons.alt_route_rounded,
            accentColor: Color(0xFF0284C7),
          ),
          TutorialStep(
            tag: 'Student Lists',
            title: 'Stop-by-Stop Student Rosters',
            description:
                'Access the complete verified roster of students assigned to each stop. View student photos, classes, parent contact numbers, and special medical notes.',
            highlight: 'Complete student profiles and guardian contact numbers at your fingertips.',
            icon: Icons.people_alt_rounded,
            accentColor: Color(0xFF6366F1),
          ),
          TutorialStep(
            tag: 'Mark Boarding',
            title: 'Mark Boarding Attendance & QR Scanning',
            description:
                'Tap "Boarded" or scan student digital QR transit passes as children enter the bus. Students on approved leave are clearly marked so you don\'t wait.',
            highlight: 'Fast, error-free attendance verification with instant confirmation.',
            icon: Icons.how_to_reg_rounded,
            accentColor: Color(0xFF10B981),
          ),
          TutorialStep(
            tag: 'Mark Dropping',
            title: 'Mark Dropping Attendance Safely',
            description:
                'As students reach the school gates or evening neighborhood stops, verify and mark their drop-off attendance and ensure all personal belongings are taken.',
            highlight: 'Guarantees that every child reaches their designated drop destination safely.',
            icon: Icons.check_circle_rounded,
            accentColor: Color(0xFF14B8A6),
          ),
          TutorialStep(
            tag: 'Verify Security PIN',
            title: 'Verify Student Security PIN',
            description:
                'Cross-check the guardian\'s security PIN before releasing young children at afternoon drop stops to ensure the person receiving the child is authorized.',
            highlight: 'Strict guardian verification prevents unauthorized child pickups.',
            icon: Icons.pin_rounded,
            accentColor: Color(0xFF8B5CF6),
          ),
          TutorialStep(
            tag: 'Trip Status & Sweep',
            title: 'Monitor Trip Status & Bus Sweep',
            description:
                'Monitor active trip progression and perform the mandatory "No Child Left Behind" end-of-trip physical seat check from front to back of the bus.',
            highlight: 'Mandatory final safety sweep guarantees no child is left behind.',
            icon: Icons.fact_check_rounded,
            accentColor: Color(0xFFF59E0B),
          ),
          TutorialStep(
            tag: 'Alerts & SOS',
            title: 'Notifications & Emergency Features',
            description:
                'Stay updated on parent leave submissions, view route notifications, and trigger the emergency SOS distress button during road breakdowns or emergencies.',
            highlight: 'Direct emergency channel to school transport coordinators.',
            icon: Icons.emergency_rounded,
            accentColor: Color(0xFFEF4444),
          ),
        ];
    }
  }

  String get _roleBadgeTitle {
    switch (_selectedRole) {
      case TutorialRole.parent:
        return 'Parent Onboarding Guide';
      case TutorialRole.driver:
        return 'Driver Onboarding Guide';
      case TutorialRole.helper:
        return 'Helper Onboarding Guide';
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final steps = _currentSteps;
    final isLastStep = _currentPage == steps.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
            children: [
              // Top Bar with Logo & Skip Action
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
                child: Row(
                  children: [
                    const EthiyoLogo(width: 130),
                    const Spacer(),
                    TextButton(
                      onPressed: _completeTutorial,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.slate,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      child: Text(widget.isStandalone ? 'Close' : 'Skip Tutorial'),
                    ),
                  ],
                ),
              ),

              // Role Selector or Locked Role Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.lockRole ? _roleBadgeTitle : 'How to Use SafeRoute',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandDeep,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Step ${_currentPage + 1} of ${steps.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.lockRole
                          ? 'Follow this quick tutorial to get started with your role features:'
                          : 'Select your role below to view your personalized guide:',
                      style: const TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w500),
                    ),
                    if (!widget.lockRole) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _RoleTab(
                              title: 'Parent',
                              icon: Icons.family_restroom_rounded,
                              selected: _selectedRole == TutorialRole.parent,
                              onTap: () => _onRoleChanged(TutorialRole.parent),
                            ),
                            _RoleTab(
                              title: 'Driver',
                              icon: Icons.directions_bus_rounded,
                              selected: _selectedRole == TutorialRole.driver,
                              onTap: () => _onRoleChanged(TutorialRole.driver),
                            ),
                            _RoleTab(
                              title: 'Helper',
                              icon: Icons.shield_rounded,
                              selected: _selectedRole == TutorialRole.helper,
                              onTap: () => _onRoleChanged(TutorialRole.helper),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Tutorial Slide PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: steps.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return _TutorialCard(step: step, stepIndex: index, totalSteps: steps.length);
                  },
                ),
              ),

              // Bottom Indicator & Next / Start / Previous Buttons
              Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, insets.bottom > 0 ? 10 : 20),
                child: Row(
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(
                        steps.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 5),
                          width: _currentPage == i ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _currentPage == i ? AppColors.brand : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Previous button if past step 0
                    if (_currentPage > 0) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandDeep,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Next / Finish button
                    ElevatedButton(
                      onPressed: () {
                        if (isLastStep) {
                          _completeTutorial();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 2,
                        shadowColor: AppColors.brand.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLastStep ? (widget.isStandalone ? 'Got it!' : 'Finish') : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Icon(isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.brand : AppColors.slate,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.brandDeep : AppColors.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
  });

  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Illustration Frame
          Container(
            height: 185,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  step.accentColor.withValues(alpha: 0.12),
                  step.accentColor.withValues(alpha: 0.04),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: step.accentColor.withValues(alpha: 0.2)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background radial circles
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.accentColor.withValues(alpha: 0.08),
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.accentColor.withValues(alpha: 0.15),
                  ),
                ),
                // Center Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [step.accentColor, step.accentColor.withValues(alpha: 0.85)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: step.accentColor.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(step.icon, color: Colors.white, size: 36),
                ),
                // Step badge top left
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Step ${stepIndex + 1} of $totalSteps',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: step.accentColor,
                      ),
                    ),
                  ),
                ),
                // Feature tag top right
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: step.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      step.tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: step.accentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.brandDeep,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.slate,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Highlight / Tip Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_rounded, color: step.accentColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.highlight,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
