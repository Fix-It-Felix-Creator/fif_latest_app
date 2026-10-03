import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/data/uk_trade_requirements.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../core/utils/image_validator.dart';
import '../../../models/trade_requirement.dart';
import '../confirm_details_screen.dart';

/// Trade qualifications upload screen for tradesman registration.
/// Shows trade-specific document requirements and allows uploading.
/// Inserted after selfie upload, before confirm details.
class TradeQualificationsScreen extends StatefulWidget {
  final Map<String, dynamic> previousData;

  const TradeQualificationsScreen({super.key, required this.previousData});

  @override
  State<TradeQualificationsScreen> createState() =>
      _TradeQualificationsScreenState();
}

class _TradeQualificationsScreenState extends State<TradeQualificationsScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late String _tradeKey;
  late List<TradeRequirement> _requirements;
  late Map<RequirementCategory, List<TradeRequirement>> _grouped;

  /// Map of requirementId -> local file path
  final Map<String, String> _uploadedFiles = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _tradeKey = widget.previousData['trade'] as String? ?? '';
    _requirements = UkTradeRequirements.getRequirementsForTrade(_tradeKey);
    _grouped = UkTradeRequirements.getGroupedRequirements(_tradeKey);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int get _mandatoryCount =>
      _requirements.where((r) => r.isMandatory).length;

  int get _mandatoryUploaded => _requirements
      .where((r) => r.isMandatory && _uploadedFiles.containsKey(r.id))
      .length;

  bool get _allMandatoryUploaded => _mandatoryUploaded >= _mandatoryCount;

  void _onContinue() {
    final allData = <String, dynamic>{
      ...widget.previousData,
      'qualificationFiles': Map<String, String>.from(_uploadedFiles),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmDetailsScreen(data: allData),
      ),
    );
  }

  void _onSkip() {
    final allData = <String, dynamic>{
      ...widget.previousData,
      'qualificationFiles': <String, String>{},
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmDetailsScreen(data: allData),
      ),
    );
  }

  void _showUploadOptions(TradeRequirement requirement) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Upload ${requirement.name}',
                    style: theme.textTheme.h4),
                const SizedBox(height: 20),
                ShadButton.outline(
                  width: double.infinity,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera, requirement.id);
                  },
                  leading: const Icon(LucideIcons.camera, size: 18),
                  child: const Text('Take Photo'),
                ),
                const SizedBox(height: 8),
                ShadButton.outline(
                  width: double.infinity,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery, requirement.id);
                  },
                  leading: const Icon(LucideIcons.image, size: 18),
                  child: const Text('Choose Image from Gallery'),
                ),
                const SizedBox(height: 8),
                ShadButton.outline(
                  width: double.infinity,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickPdf(requirement.id);
                  },
                  leading: const Icon(LucideIcons.fileText, size: 18),
                  child: const Text('Choose PDF Document'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, String reqId) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final error = await ImageValidator.validateExtraDocument(file);
      if (error != null) {
        if (mounted) {
          CommonToasts.error(context, error, title: 'File Too Large');
        }
        return;
      }

      setState(() {
        _uploadedFiles[reqId] = picked.path;
      });
    } catch (e) {
      if (mounted) {
        CommonToasts.error(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _pickPdf(String reqId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final file = File(filePath);

      final error = await ImageValidator.validateExtraDocument(file);
      if (error != null) {
        if (mounted) {
          CommonToasts.error(context, error, title: 'File Too Large');
        }
        return;
      }

      setState(() {
        _uploadedFiles[reqId] = filePath;
      });
    } catch (e) {
      if (mounted) {
        CommonToasts.error(context, 'Failed to pick PDF: $e');
      }
    }
  }

  void _removeFile(String reqId) {
    setState(() {
      _uploadedFiles.remove(reqId);
    });
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 500;
    if (deviceInfo.isTablet) return 480;
    return 400;
  }

  EdgeInsets _getContentPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return const EdgeInsets.all(40);
    if (deviceInfo.isTablet) return const EdgeInsets.all(32);
    return const EdgeInsets.all(24);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(theme, deviceInfo),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      padding: _getContentPadding(deviceInfo),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _getMaxWidth(deviceInfo),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProgressSection(theme, deviceInfo),
                              SizedBox(height: deviceInfo.isTablet ? 20 : 16),
                              _buildProgressBar(theme, deviceInfo),
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),
                              ..._buildCategorySections(
                                theme,
                                isDark,
                                deviceInfo,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomButton(theme, deviceInfo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ShadButton.ghost(
              width: deviceInfo.isTablet ? 48 : 44,
              height: deviceInfo.isTablet ? 48 : 44,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: Icon(
                LucideIcons.chevronLeft,
                size: deviceInfo.isTablet ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Qualifications',
              style:
                  (deviceInfo.isTablet
                          ? theme.textTheme.h2
                          : theme.textTheme.h3)
                      .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ShadButton.ghost(
            onPressed: _onSkip,
            child: Text(
              'Skip',
              style: TextStyle(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w500,
                fontSize: deviceInfo.isTablet ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Trade Qualifications',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload your required trade qualifications and certifications',
          style: theme.textTheme.muted.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProgressBar(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.lightbulb,
            size: deviceInfo.isTablet ? 20 : 18,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: deviceInfo.isTablet ? 12 : 10),
          Expanded(
            child: Text(
              'We suggest uploading your qualifications now to speed up your verification.',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySections(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    final widgets = <Widget>[];

    // Category ordering
    const categoryOrder = [
      RequirementCategory.legal,
      RequirementCategory.safety,
      RequirementCategory.qualification,
      RequirementCategory.tradeSpecific,
    ];

    for (final category in categoryOrder) {
      final reqs = _grouped[category];
      if (reqs == null || reqs.isEmpty) continue;

      final label = reqs.first.categoryLabel;
      final icon = _categoryIcon(category);
      final color = _categoryColor(category);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: (deviceInfo.isTablet
                        ? theme.textTheme.h4
                        : theme.textTheme.large)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

      for (final req in reqs) {
        widgets.add(
          _buildRequirementCard(req, theme, isDark, deviceInfo),
        );
        widgets.add(SizedBox(height: deviceInfo.isTablet ? 12 : 10));
      }

      widgets.add(SizedBox(height: deviceInfo.isTablet ? 16 : 12));
    }

    return widgets;
  }

  IconData _categoryIcon(RequirementCategory category) {
    switch (category) {
      case RequirementCategory.legal:
        return LucideIcons.scale;
      case RequirementCategory.safety:
        return LucideIcons.shieldCheck;
      case RequirementCategory.qualification:
        return LucideIcons.graduationCap;
      case RequirementCategory.tradeSpecific:
        return LucideIcons.wrench;
    }
  }

  Color _categoryColor(RequirementCategory category) {
    switch (category) {
      case RequirementCategory.legal:
        return const Color(0xFF3B82F6);
      case RequirementCategory.safety:
        return const Color(0xFFF59E0B);
      case RequirementCategory.qualification:
        return const Color(0xFF8B5CF6);
      case RequirementCategory.tradeSpecific:
        return const Color(0xFF10B981);
    }
  }

  Widget _buildRequirementCard(
    TradeRequirement req,
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    final isUploaded = _uploadedFiles.containsKey(req.id);
    final filePath = _uploadedFiles[req.id];
    final isPdf = filePath?.toLowerCase().endsWith('.pdf') ?? false;

    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.8)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded
              ? Colors.green.withValues(alpha: 0.5)
              : theme.colorScheme.border.withValues(alpha: 0.5),
          width: isUploaded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            req.name,
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: deviceInfo.isTablet ? 14 : 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      req.description,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                        fontSize: 11,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isUploaded)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (isUploaded) ...[
            // Show uploaded file info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPdf ? LucideIcons.fileText : LucideIcons.image,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Document uploaded',
                      style: theme.textTheme.small.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Re-upload
                  GestureDetector(
                    onTap: () => _showUploadOptions(req),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        LucideIcons.refreshCw,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Remove
                  GestureDetector(
                    onTap: () => _removeFile(req.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        LucideIcons.trash2,
                        size: 14,
                        color: theme.colorScheme.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Upload button
            ShadButton.outline(
              width: double.infinity,
              size: ShadButtonSize.sm,
              onPressed: () => _showUploadOptions(req),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.upload,
                    size: 16,
                    color: theme.colorScheme.foreground,
                  ),
                  const SizedBox(width: 8),
                  const Text('Upload Document'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomButton(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: _getContentPadding(deviceInfo),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_allMandatoryUploaded && _uploadedFiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'You can upload remaining documents later from Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ShadButton(
                width: double.infinity,
                height: deviceInfo.isTablet ? 52 : 48,
                onPressed: _onContinue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _uploadedFiles.isEmpty ? 'Skip & Continue' : 'Continue',
                      style: TextStyle(
                        color: theme.colorScheme.primaryForeground,
                        fontWeight: FontWeight.w600,
                        fontSize: deviceInfo.isTablet ? 16 : 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: theme.colorScheme.primaryForeground,
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
