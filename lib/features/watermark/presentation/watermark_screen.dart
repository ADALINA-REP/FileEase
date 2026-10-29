import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/result_bottom_sheet.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';
import '../../../services/image_service.dart';

class WatermarkScreen extends StatefulWidget {
  final SelectedFileItem? initialFile;

  const WatermarkScreen({super.key, this.initialFile});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  SelectedFileItem? _selectedFile;
  ImageMetadataInfo? _metadata;
  bool _isProcessing = false;

  final TextEditingController _textController = TextEditingController(
    text: 'CONFIDENTIAL - FOR OFFICIAL USE ONLY',
  );

  WatermarkStyle _selectedStyle = WatermarkStyle.tiled;
  double _opacity = 0.50;
  int _selectedColor = 0xFFD32F2F; // Red security default
  int _fontSize = 48;

  // Normalized position for stamp mode [0.0 - 1.0]
  double _stampX = 0.5;
  double _stampY = 0.5;

  final List<int> _colorPalette = [
    0xFFD32F2F, // Security Red
    0xFF1976D2, // Official Blue
    0xFF2E7D32, // Emerald Green
    0xFFE65100, // Vibrant Orange
    0xFF7B1FA2, // Royal Purple
    0xFF212121, // Charcoal Black
    0xFFFFFFFF, // Pure White
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FileService.pickSingleImage();
    if (picked != null) {
      _loadFile(picked);
    }
  }

  Future<void> _loadFile(SelectedFileItem file) async {
    setState(() {
      _selectedFile = file;
    });

    final meta = await ImageService.extractMetadata(file.bytes);
    if (mounted) {
      setState(() {
        _metadata = meta;
      });
    }
  }

  void _addCurrentDate() {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final current = _textController.text.trim();
    if (current.contains(today)) return;

    setState(() {
      if (current.isEmpty) {
        _textController.text = today;
      } else {
        _textController.text = '$current ($today)';
      }
    });
  }

  Future<void> _executeWatermark() async {
    if (_selectedFile == null || _isProcessing) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await ImageService.applyWatermark(
        bytes: _selectedFile!.bytes,
        watermarkText: _textController.text.trim(),
        style: _selectedStyle,
        opacity: _opacity,
        colorValue: _selectedColor,
        fontSize: _fontSize,
        customX: _stampX,
        customY: _stampY,
        quality: 95,
      );

      final baseName = _selectedFile!.name.replaceAll(
        RegExp(r'\.[a-zA-Z0-9]+$'),
        '',
      );
      final outputName = '${baseName}_protected.jpg';

      final savedFile = await FileService.saveExportFile(
        bytes: result.bytes,
        fileName: outputName,
      );

      await HistoryService.instance.addEntry(
        toolTitle: l10n.t('tool_watermark'),
        fileName: outputName,
        filePath: savedFile.path,
        originalBytes: _selectedFile!.sizeInBytes,
        resultBytes: result.sizeInBytes,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        await ResultBottomSheet.show(
          context: context,
          title: l10n.t('success_title'),
          fileName: outputName,
          file: savedFile,
          originalBytes: _selectedFile!.sizeInBytes,
          resultBytes: result.sizeInBytes,
          rawInputBytes: _selectedFile!.bytes,
          rawResultBytes: result.bytes,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('tool_watermark')),
        actions: [
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: l10n.t('choose_image'),
              onPressed: _isProcessing ? null : _pickImage,
            ),
        ],
      ),
      body: _selectedFile == null
          ? _buildEmptyPicker(context)
          : _buildWorkspace(context),
      bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
    );
  }

  Widget _buildEmptyPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.skyLight.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 64,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.t('select_photo_prompt'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('tool_watermark_desc'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(l10n.t('choose_image')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final watermarkColor = Color(_selectedColor).withValues(alpha: _opacity);
    final watermarkBgColor =
        Color(_selectedColor).withValues(alpha: _opacity * 0.4);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // WYSIWYG Interactive Photo Preview Card
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 260,
              color: Colors.black,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imgW = _metadata?.width ?? 1;
                  final imgH = _metadata?.height ?? 1;
                  final imgAspect = imgW / imgH;
                  final containerAspect =
                      constraints.maxWidth / constraints.maxHeight;

                  double renderW, renderH, renderX, renderY;
                  if (containerAspect > imgAspect) {
                    renderH = constraints.maxHeight;
                    renderW = constraints.maxHeight * imgAspect;
                    renderX = (constraints.maxWidth - renderW) / 2;
                    renderY = 0.0;
                  } else {
                    renderW = constraints.maxWidth;
                    renderH = constraints.maxWidth / imgAspect;
                    renderX = 0.0;
                    renderY = (constraints.maxHeight - renderH) / 2;
                  }

                  final photoRect =
                      Rect.fromLTWH(renderX, renderY, renderW, renderH);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo
                      Positioned.fromRect(
                        rect: photoRect,
                        child: Image.memory(
                          _selectedFile!.bytes,
                          fit: BoxFit.fill,
                        ),
                      ),

                      // Watermark Overlay restricted strictly to photoRect
                      Positioned.fromRect(
                        rect: photoRect,
                        child: ClipRect(
                          child: _buildPreviewOverlay(
                            watermarkColor,
                            watermarkBgColor,
                            photoRect.size,
                          ),
                        ),
                      ),

                      // Gesture Detector for draggable Stamp Mode
                      if (_selectedStyle == WatermarkStyle.stamp)
                        Positioned.fromRect(
                          rect: photoRect,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanUpdate: (details) {
                              setState(() {
                                _stampX = (_stampX +
                                        details.delta.dx / photoRect.width)
                                    .clamp(0.1, 0.9);
                                _stampY = (_stampY +
                                        details.delta.dy / photoRect.height)
                                    .clamp(0.1, 0.9);
                              });
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Watermark Style Selector
          Text(
            l10n.t('watermark_style'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          SegmentedButton<WatermarkStyle>(
            segments: [
              ButtonSegment(
                value: WatermarkStyle.tiled,
                label: Text(l10n.t('watermark_tiled')),
                icon: const Icon(Icons.grid_4x4_rounded),
              ),
              ButtonSegment(
                value: WatermarkStyle.banner,
                label: Text(l10n.t('watermark_banner')),
                icon: const Icon(Icons.horizontal_rule_rounded),
              ),
              ButtonSegment(
                value: WatermarkStyle.stamp,
                label: Text(l10n.t('watermark_stamp')),
                icon: const Icon(Icons.touch_app_rounded),
              ),
            ],
            selected: {_selectedStyle},
            onSelectionChanged: (val) {
              setState(() {
                _selectedStyle = val.first;
              });
            },
          ),
          const SizedBox(height: 16),

          // Security Text Input & Quick Preset Chips
          Text(
            l10n.t('watermark_text_label'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: l10n.t('watermark_hint'),
              prefixIcon: const Icon(Icons.edit_note_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_rounded, size: 20),
                tooltip: l10n.t('add_date_btn'),
                onPressed: _addCurrentDate,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Quick Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(l10n.t('preset_rent')),
                const SizedBox(width: 8),
                _buildPresetChip(l10n.t('preset_bank')),
                const SizedBox(width: 8),
                _buildPresetChip(l10n.t('preset_copy')),
                const SizedBox(width: 8),
                _buildPresetChip(l10n.t('preset_exam')),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Opacity Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.t('watermark_opacity'),
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              Text(
                '${(_opacity * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          Slider(
            value: _opacity,
            min: 0.15,
            max: 0.85,
            divisions: 14,
            activeColor: AppColors.primaryBlue,
            label: '${(_opacity * 100).round()}%',
            onChanged: (val) => setState(() => _opacity = val),
          ),
          const SizedBox(height: 10),

          // Color Palette & Font Size
          Row(
            children: [
              // Color selection
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('watermark_color'),
                      style:
                          theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._colorPalette.map((colorVal) {
                            final isSelected = _selectedColor == colorVal;
                            final color = Color(colorVal);
                            final isLight = (color.r * 255 * 0.299 +
                                    color.g * 255 * 0.587 +
                                    color.b * 255 * 0.114) >
                                186;

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = colorVal),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : (isDark
                                            ? Colors.white30
                                            : Colors.black26),
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: AppColors.primaryBlue
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: isLight
                                            ? Colors.black
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          }),

                          // Custom Color Picker Button
                          GestureDetector(
                            onTap: _openCustomColorPicker,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.amber,
                                    Colors.green,
                                    Colors.cyan,
                                    Colors.blue,
                                    Colors.purple,
                                    Colors.red,
                                  ],
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black38,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.colorize_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Font Size Selector (Normale / Grande)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('watermark_font_size'),
                      style:
                          theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 24, label: Text('S')),
                        ButtonSegment(value: 48, label: Text('L')),
                      ],
                      selected: {_fontSize},
                      onSelectionChanged: (val) {
                        setState(() {
                          _fontSize = val.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Main Action Button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _executeWatermark,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shield_rounded),
            label: Text(
              _isProcessing
                  ? l10n.t('processing')
                  : l10n.t('apply_watermark_btn'),
            ),
          ),
        ],
      ),
    );
  }

  void _openCustomColorPicker() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int r = (_selectedColor >> 16) & 0xFF;
    int g = (_selectedColor >> 8) & 0xFF;
    int b = _selectedColor & 0xFF;

    final List<Color> swatchHues = [
      const Color(0xFFE53935), // Red
      const Color(0xFFD81B60), // Pink
      const Color(0xFF8E24AA), // Purple
      const Color(0xFF3949AB), // Indigo
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF00ACC1), // Cyan
      const Color(0xFF00897B), // Teal
      const Color(0xFF43A047), // Green
      const Color(0xFF7CB342), // Light Green
      const Color(0xFFFDD835), // Yellow
      const Color(0xFFFB8C00), // Orange
      const Color(0xFFF4511E), // Deep Orange
      const Color(0xFF6D4C41), // Brown
      const Color(0xFF546E7A), // Blue Grey
      const Color(0xFF212121), // Charcoal
      const Color(0xFFFFFFFF), // White
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentColorVal = (255 << 24) | (r << 16) | (g << 8) | b;
            final previewColor = Color(currentColorVal);
            final hexCode =
                '#${(currentColorVal & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
            final isLight = (r * 0.299 + g * 0.587 + b * 0.114) > 186;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.palette_rounded,
                              color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Text(
                            l10n.t('custom_color'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: previewColor.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: previewColor, width: 1.5),
                        ),
                        child: Text(
                          hexCode,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: previewColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _textController.text.trim().isEmpty
                          ? l10n.t('preview_text')
                          : _textController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: swatchHues.map((hue) {
                      final hueVal = hue.toARGB32();
                      final isCurrent =
                          (hueVal & 0xFFFFFF) == (currentColorVal & 0xFFFFFF);
                      final hueR = (hueVal >> 16) & 0xFF;
                      final hueG = (hueVal >> 8) & 0xFF;
                      final hueB = hueVal & 0xFF;
                      final isHueLight =
                          (hueR * 0.299 + hueG * 0.587 + hueB * 0.114) > 186;

                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            r = hueR;
                            g = hueG;
                            b = hueB;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: hue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.primaryBlue
                                  : (isDark
                                      ? Colors.white30
                                      : Colors.black26),
                              width: isCurrent ? 2.5 : 1,
                            ),
                          ),
                          child: isCurrent
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: isHueLight
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _buildRgbSlider(
                    label: 'R',
                    value: r,
                    activeColor: Colors.redAccent,
                    onChanged: (val) => setSheetState(() => r = val.round()),
                  ),
                  _buildRgbSlider(
                    label: 'G',
                    value: g,
                    activeColor: Colors.greenAccent.shade700,
                    onChanged: (val) => setSheetState(() => g = val.round()),
                  ),
                  _buildRgbSlider(
                    label: 'B',
                    value: b,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) => setSheetState(() => b = val.round()),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final pickedVal = currentColorVal;
                      setState(() {
                        _selectedColor = pickedVal;
                        if (!_colorPalette.contains(pickedVal)) {
                          _colorPalette.insert(0, pickedVal);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.t('select_color')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRgbSlider({
    required String label,
    required int value,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: activeColor,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewOverlay(
    Color textColor,
    Color bannerBgColor,
    Size size,
  ) {
    final text = _textController.text.isEmpty
        ? 'COPIE CONFORME'
        : _textController.text.trim();

    if (_selectedStyle == WatermarkStyle.tiled) {
      // High-precision anti-fraud grid custom painter (Guaranteed 0 overlap)
      return CustomPaint(
        size: size,
        painter: WatermarkTiledPainter(
          text: text,
          color: textColor,
          fontSize: _fontSize == 48 ? 12 : 9.5,
        ),
      );
    } else if (_selectedStyle == WatermarkStyle.banner) {
      // Central Banner
      return Center(
        child: Transform.rotate(
          angle: -0.25,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: bannerBgColor,
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: _fontSize == 48 ? 14 : 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      );
    } else {
      // Stamp / Free Drag Mode
      return Stack(
        children: [
          Positioned(
            left: _stampX * size.width - 60,
            top: _stampY * size.height - 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bannerBgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: textColor, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: textColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: _fontSize == 48 ? 12 : 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildPresetChip(String presetText) {
    return ActionChip(
      label: Text(
        presetText,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      onPressed: () {
        setState(() {
          _textController.text = presetText;
        });
      },
    );
  }
}

/// Custom painter for anti-fraud diagonal grid watermark.
/// Mathematically spaces rows and columns to prevent overlapping.
class WatermarkTiledPainter extends CustomPainter {
  final String text;
  final Color color;
  final double fontSize;
  final double angle;

  WatermarkTiledPainter({
    required this.text,
    required this.color,
    required this.fontSize,
    this.angle = -0.40, // ~-23 degrees diagonal anti-fraud slant
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || text.isEmpty) return;

    final textStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    // Generous diagonal dimension to ensure full rotated coverage
    final diag =
        math.sqrt(size.width * size.width + size.height * size.height) * 1.5;

    // Horizontal spacing: full text width + guaranteed gap (at least 42px or 25% of text width)
    final itemSpacing = textWidth + math.max(42.0, textWidth * 0.25);

    // Vertical line spacing: at least 3.2x text height so lines NEVER touch
    final lineSpacing = math.max(textHeight * 3.2, 34.0);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-diag / 2, -diag / 2);

    int rowIndex = 0;
    for (double y = 0; y < diag; y += lineSpacing) {
      final double startX = (rowIndex % 2 == 0) ? 0.0 : -(itemSpacing / 2);
      for (double x = startX - itemSpacing;
          x < diag + itemSpacing;
          x += itemSpacing) {
        textPainter.paint(canvas, Offset(x, y));
      }
      rowIndex++;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WatermarkTiledPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.color != color ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.angle != angle;
  }
}

