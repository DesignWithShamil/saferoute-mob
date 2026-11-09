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
    this.initialRole = TutorialRole.parent,
    this.isStandalone = false,
  });

  final VoidCallback onFinished;
  final TutorialRole initialRole;
  final bool isStandalone;

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
    await storage.markTutorialSeen();
    if (!mounted) return;
    widget.onFinished();
  }

  List<TutorialStep> get _currentSteps {
    switch (_selectedRole) {
      case TutorialRole.parent:
        return const [
          TutorialStep(
            tag: 'Live Map & Tracking',
            title: 'Track School Bus Live on Map',
            description:
                'See the exact real-time GPS location of your child\'s school bus as it moves along its route. View estimated arrival times (ETA) at your pickup and drop stops so you never wait in the rain or heat.',
            highlight: 'Live route updates & accurate arrival estimates on an interactive map.',
            icon: Icons.location_on_rounded,
            accentColor: Color(0xFF1585E8),
          ),
          TutorialStep(
            tag: 'Boarding & Safety Alerts',
            title: 'Instant Boarding & Drop-Off Alerts',
            description:
                'Receive immediate push notifications the second your child safely steps onto the bus in the morning and when they safely enter or leave the school campus.',
            highlight: 'Instant notifications keeping you informed every step of the journey.',
            icon: Icons.notifications_active_rounded,
            accentColor: Color(0xFF12A594),
          ),
          TutorialStep(
            tag: 'Attendance & Leaves',
            title: 'View Attendance & Apply for Leaves',
            description:
                'Review your child\'s transport attendance records. If your child will not be attending school, submit a leave request with one tap so the driver knows not to wait at your stop.',
            highlight: 'One-tap leave application saves bus route time and prevents delays.',
            icon: Icons.event_note_rounded,
            accentColor: Color(0xFF6366F1),
          ),
          TutorialStep(
            tag: 'Safety & Direct Contact',
            title: 'Direct Driver Contact & Safety SOS',
            description:
                'Connect directly with the assigned bus driver and helper, or reach out to the school transport coordinator in case of emergencies or route inquiries.',
            highlight: 'Verified contact details always available at your fingertips.',
            icon: Icons.phone_in_talk_rounded,
            accentColor: Color(0xFF0284C7),
          ),
        ];

      case TutorialRole.driver:
        return const [
          TutorialStep(
            tag: 'Route Schedules',
            title: 'Assigned Routes & Sequential Stops',
            description:
                'Access your daily morning and evening route plans. View sequential pickup and drop stops plotted clearly on the map along with student counts for each stop.',
            highlight: 'Clear route overview with sequential stops and student numbers.',
            icon: Icons.alt_route_rounded,
            accentColor: Color(0xFF1585E8),
          ),
          TutorialStep(
            tag: 'Trip Execution',
            title: 'One-Tap Trip Start & Live GPS Streaming',
            description:
                'Tap "Start Trip" when beginning your journey. SafeRoute automatically broadcasts your real-time GPS location in the background to waiting parents and school admin.',
            highlight: 'Battery-efficient background GPS tracking runs reliably while driving.',
            icon: Icons.play_circle_filled_rounded,
            accentColor: Color(0xFF16A34A),
          ),
          TutorialStep(
            tag: 'Delay Management',
            title: 'Report Traffic & Route Delays',
            description:
                'Encountered unexpected traffic, vehicle issues, or bad weather? Tap to broadcast a 5, 10, or 15-minute delay to waiting parents automatically.',
            highlight: 'Keeps parents informed and prevents repeated phone calls while driving.',
            icon: Icons.access_time_filled_rounded,
            accentColor: Color(0xFF0284C7),
          ),
          TutorialStep(
            tag: 'Emergency SOS',
            title: 'Emergency SOS Distress Broadcast',
            description:
                'In any critical road incident or emergency breakdown, tap the SOS button to instantly alert the school transport management and trigger rapid response.',
            highlight: 'Immediate dispatch support directly to school authorities.',
            icon: Icons.emergency_rounded,
            accentColor: Color(0xFFDC2626),
          ),
        ];

      case TutorialRole.helper:
        return const [
          TutorialStep(
            tag: 'Student Roster',
            title: 'Stop-by-Stop Student Boarding Roster',
            description:
                'View the verified roster of students scheduled for each stop. Know exactly who is boarding, who is dropping off, and who is on approved leave today.',
            highlight: 'Students on leave are clearly flagged so you do not wait unnecessarily.',
            icon: Icons.checklist_rounded,
            accentColor: Color(0xFF1585E8),
          ),
          TutorialStep(
            tag: 'Quick Attendance',
            title: 'QR Code Scanning & One-Tap Boarding',
            description:
                'Scan student QR identity cards with your camera or tap "Boarded" to mark attendance in under two seconds with instant auditory confirmation.',
            highlight: 'Fast, error-free attendance verification at every stop.',
            icon: Icons.qr_code_scanner_rounded,
            accentColor: Color(0xFF12A594),
          ),
          TutorialStep(
            tag: 'Parent Contact',
            title: 'One-Tap Parent Contact Details',
            description:
                'If a student hasn\'t reached the stop on time, tap their profile card to call their parent or emergency guardian immediately from the app.',
            highlight: 'Instant access to parent phone numbers for every student on board.',
            icon: Icons.contact_phone_rounded,
            accentColor: Color(0xFF6366F1),
          ),
          TutorialStep(
            tag: 'Safety Verification',
            title: 'Mandatory "No Child Left Behind" Sweep',
            description:
                'Perform the mandatory physical seat sweep from front to back of the bus to ensure every child has safely alighted before completing the trip.',
            highlight: 'Mandatory safety protocol protecting every single student.',
            icon: Icons.verified_user_rounded,
            accentColor: Color(0xFF16A34A),
          ),
        ];
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
          child: Column(
            children: [
              // Header with Logo & Skip Action
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
                child: Row(
                  children: [
                    const EthiyoLogo(width: 140),
                    const Spacer(),
                    TextButton(
                      onPressed: _completeTutorial,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.slate,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      child: Text(widget.isStandalone ? 'Close' : 'Skip'),
                    ),
                  ],
                ),
              ),

              // Role Selector Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'How to Use SafeRoute',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Select your user role to view your step-by-step guide:',
                      style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    // 3 Role Tabs
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

              // Bottom Indicator & Next / Start Buttons
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
                          margin: const EdgeInsets.only(right: 6),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i ? AppColors.brand : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Back button if past step 0
                    if (_currentPage > 0) ...[
                      IconButton.filledTonal(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: AppColors.brandDeep,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    // Next / Get Started button
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
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        elevation: 2,
                        shadowColor: AppColors.brand.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLastStep ? (widget.isStandalone ? 'Got it!' : 'Get Started') : 'Next',
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
            height: 190,
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

          // Highlight Box
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

