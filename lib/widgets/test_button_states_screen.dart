import 'package:flutter/material.dart';
import 'common/fj_button.dart';
import 'button.dart';
import 'package:fufajis_online/constants/app_colors.dart';

/// Test Screen: Button Component - All States
///
/// Visual test for all button variants and states:
/// - PRIMARY: default, hover, active, disabled, loading, error
/// - SECONDARY: default, hover, active, disabled, loading, error
/// - OUTLINE: default, hover, active, disabled, loading, error
/// - DANGER: default, hover, active, disabled, loading, error
/// - TEXT: default, hover, active, disabled, loading, error
/// - SUCCESS: default, hover, active, disabled, loading, error
/// - INFO: default, hover, active, disabled, loading, error
///
/// Keyboard Testing:
/// - Tab: Navigate to any button
/// - Enter/Space: Activate button
/// - Focus Ring: Should appear as 2px orange border
///
/// Touch Testing:
/// - Long press: Should show ripple effect
/// - Double tap: Should activate twice
/// - Disabled: No interaction, no ripple
class TestButtonStatesScreen extends StatefulWidget {
  const TestButtonStatesScreen({super.key});

  @override
  State<TestButtonStatesScreen> createState() => _TestButtonStatesScreenState();
}

class _TestButtonStatesScreenState extends State<TestButtonStatesScreen> {
  bool _isLoadingPrimary = false;
  bool _isLoadingSecondary = false;
  bool _isLoadingOutline = false;
  bool _isLoadingDanger = false;

  void _handlePrimaryPress() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primary button pressed')),
    );
  }

  void _handleSecondaryPress() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Secondary button pressed')),
    );
  }

  void _handleLoadingPrimary() {
    setState(() => _isLoadingPrimary = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoadingPrimary = false);
    });
  }

  void _handleLoadingSecondary() {
    setState(() => _isLoadingSecondary = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoadingSecondary = false);
    });
  }

  void _handleLoadingOutline() {
    setState(() => _isLoadingOutline = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoadingOutline = false);
    });
  }

  void _handleLoadingDanger() {
    setState(() => _isLoadingDanger = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoadingDanger = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Button Component Test'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PRIMARY BUTTON VARIANTS
            _buildSection(
              title: 'PRIMARY BUTTON (FjButtonType.primary)',
              description: 'Orange background, white text',
              children: [
                FjButton(
                  label: 'Default',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.primary,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'With Icon',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.primary,
                  icon: Icons.add,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Loading',
                  onPressed: _handleLoadingPrimary,
                  type: FjButtonType.primary,
                  isLoading: _isLoadingPrimary,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Disabled',
                  onPressed: null,
                  type: FjButtonType.primary,
                  isDisabled: true,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Error State',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.primary,
                  isError: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Keyboard Test: Tab to focus, Enter/Space to activate, ESC to unfocus',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.grey600),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // SECONDARY BUTTON VARIANTS
            _buildSection(
              title: 'SECONDARY BUTTON (FjButtonType.secondary)',
              description: 'Grey background, dark text',
              children: [
                FjButton(
                  label: 'Default',
                  onPressed: _handleSecondaryPress,
                  type: FjButtonType.secondary,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'With Icon',
                  onPressed: _handleSecondaryPress,
                  type: FjButtonType.secondary,
                  icon: Icons.edit,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Loading',
                  onPressed: _handleLoadingSecondary,
                  type: FjButtonType.secondary,
                  isLoading: _isLoadingSecondary,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Disabled',
                  onPressed: null,
                  type: FjButtonType.secondary,
                  isDisabled: true,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Error State',
                  onPressed: _handleSecondaryPress,
                  type: FjButtonType.secondary,
                  isError: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // OUTLINE BUTTON VARIANTS
            _buildSection(
              title: 'OUTLINE BUTTON (FjButtonType.outline)',
              description: 'Transparent background, orange border',
              children: [
                FjButton(
                  label: 'Default',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.outline,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'With Icon',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.outline,
                  icon: Icons.download,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Loading',
                  onPressed: _handleLoadingOutline,
                  type: FjButtonType.outline,
                  isLoading: _isLoadingOutline,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Disabled',
                  onPressed: null,
                  type: FjButtonType.outline,
                  isDisabled: true,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Error State',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.outline,
                  isError: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // DANGER BUTTON VARIANTS
            _buildSection(
              title: 'DANGER BUTTON (FjButtonType.danger)',
              description: 'Red background, white text (destructive actions)',
              children: [
                FjButton(
                  label: 'Delete Item',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.danger,
                  icon: Icons.delete,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Loading',
                  onPressed: _handleLoadingDanger,
                  type: FjButtonType.danger,
                  isLoading: _isLoadingDanger,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Disabled',
                  onPressed: null,
                  type: FjButtonType.danger,
                  isDisabled: true,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Error State',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.danger,
                  isError: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // TEXT BUTTON VARIANTS
            _buildSection(
              title: 'TEXT BUTTON (FjButtonType.text)',
              description: 'Text-only, no background',
              children: [
                FjButton(
                  label: 'Learn More',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.text,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'With Icon',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.text,
                  icon: Icons.arrow_forward,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Disabled',
                  onPressed: null,
                  type: FjButtonType.text,
                  isDisabled: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // SUCCESS BUTTON VARIANTS
            _buildSection(
              title: 'SUCCESS BUTTON (FjButtonType.success)',
              description: 'Green background, white text',
              children: [
                FjButton(
                  label: 'Confirm',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.success,
                  icon: Icons.check,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Disabled',
                  onPressed: null,
                  type: FjButtonType.success,
                  isDisabled: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // INFO BUTTON VARIANTS
            _buildSection(
              title: 'INFO BUTTON (FjButtonType.info)',
              description: 'Blue background, white text',
              children: [
                FjButton(
                  label: 'More Information',
                  onPressed: _handlePrimaryPress,
                  type: FjButtonType.info,
                  icon: Icons.info,
                ),
                const SizedBox(height: 12),
                FjButton(
                  label: 'Disabled',
                  onPressed: null,
                  type: FjButtonType.info,
                  isDisabled: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // LEGACY BUTTON WIDGET (for backward compatibility)
            _buildSection(
              title: 'LEGACY BUTTON (Button widget)',
              description: 'Maintained for backward compatibility. Use FjButton instead.',
              children: [
                Button(
                  title: 'Primary',
                  onPressed: _handlePrimaryPress,
                  isSecondary: false,
                ),
                const SizedBox(height: 12),
                Button(
                  title: 'Secondary',
                  onPressed: _handleSecondaryPress,
                  isSecondary: true,
                ),
                const SizedBox(height: 12),
                Button(
                  title: 'Disabled',
                  onPressed: null,
                  isDisabled: true,
                ),
                const SizedBox(height: 12),
                Button(
                  title: 'Error',
                  onPressed: _handlePrimaryPress,
                  isError: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // TESTING CHECKLIST
            _buildSection(
              title: 'Testing Checklist',
              description: '',
              children: [
                _buildChecklistItem('Visual: Default state shows correct colors'),
                _buildChecklistItem('Visual: Hover state changes (desktop)'),
                _buildChecklistItem('Visual: Active state changes (press)'),
                _buildChecklistItem('Visual: Disabled state is greyed out (opacity 0.6)'),
                _buildChecklistItem('Visual: Loading shows spinner, disables interaction'),
                _buildChecklistItem('Visual: Error state shows red border + text'),
                _buildChecklistItem('Keyboard: Tab navigates to buttons'),
                _buildChecklistItem('Keyboard: Focus ring visible (2px orange border)'),
                _buildChecklistItem('Keyboard: Enter/Space activates button'),
                _buildChecklistItem('Touch: Buttons respond to tap'),
                _buildChecklistItem('Touch: Ripple effect visible on enabled buttons'),
                _buildChecklistItem('Touch: Disabled buttons have no interaction'),
                _buildChecklistItem('Semantics: Screen reader announces button label'),
                _buildChecklistItem('Semantics: Disabled buttons announced as disabled'),
                _buildChecklistItem('Accessibility: All colors WCAG AA compliant'),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.grey900,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grey600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_box_outline_blank, size: 18, color: AppColors.grey500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.grey700),
            ),
          ),
        ],
      ),
    );
  }
}
