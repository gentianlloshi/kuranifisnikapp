import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../theme/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'dart:io';

class ImageGeneratorWidget extends StatefulWidget {
  final String? initialText;
  final String? initialReference;

  const ImageGeneratorWidget({
    super.key,
    this.initialText,
    this.initialReference,
  });

  @override
  State<ImageGeneratorWidget> createState() => _ImageGeneratorWidgetState();
}

class _ImageGeneratorWidgetState extends State<ImageGeneratorWidget> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  
  String _selectedFormat = 'square'; // square, story, landscape
  Color _backgroundColor = const Color(0xFF1E3A8A);
  Color _textColor = Colors.white;
  double _fontSize = 24.0;
  String? _backgroundImagePath;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _textController.text = widget.initialText!;
    }
    if (widget.initialReference != null) {
      _referenceController.text = widget.initialReference!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gjenerues Imazhesh'),
        actions: [
          IconButton(
            onPressed: _generateImage,
            icon: const Icon(Icons.download),
            tooltip: 'Shkarkoni Imazhin',
          ),
          IconButton(
            onPressed: _shareImage,
            icon: const Icon(Icons.share),
            tooltip: 'Ndani Imazhin',
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: _buildImagePreview(),
                ),
              ),
            ),
          ),

          // Controls
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Input
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Teksti i Ajetit',
                      border: OutlineInputBorder(),
                      hintText: 'Shkruani tekstin e ajetit këtu...',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Reference Input
                  TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Referenca (p.sh. Surja 2, Ajeti 255)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Format Selection
                  Text(
                    'Formati',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFormatChip('square', 'Katror', Icons.crop_square),
                      const SizedBox(width: 8),
                      _buildFormatChip('story', 'Story', Icons.crop_portrait),
                      const SizedBox(width: 8),
                      _buildFormatChip('landscape', 'Peizazh', Icons.crop_landscape),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Background Options
                  Text(
                    'Sfondi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickBackgroundImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Zgjidh Imazh'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _backgroundImagePath = null),
                        icon: const Icon(Icons.color_lens),
                        label: const Text('Ngjyrë'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Color Picker (only if no background image)
                  if (_backgroundImagePath == null) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildColorChip(const Color(0xFF1E3A8A)), // Blue
                        _buildColorChip(const Color(0xFF059669)), // Green
                        _buildColorChip(const Color(0xFF7C3AED)), // Purple
                        _buildColorChip(const Color(0xFFDC2626)), // Red
                        _buildColorChip(const Color(0xFF0891B2)), // Cyan
                        _buildColorChip(const Color(0xFF1F2937)), // Gray
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Text Color
                  Text(
                    'Ngjyra e Tekstit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTextColorChip(Colors.white),
                      _buildTextColorChip(Colors.black),
                      _buildTextColorChip(const Color(0xFFF59E0B)), // Amber
                      _buildTextColorChip(const Color(0xFF10B981)), // Emerald
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Font Size
                  Text(
                    'Madhësia e Fontit: ${_fontSize.round()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _fontSize,
                    min: 16,
                    max: 48,
                    divisions: 16,
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final size = _getImageSize();
    final dpr = MediaQuery.of(context).devicePixelRatio;
    // Decode any picked background image close to the on-screen size to avoid
    // large bitmap allocations and expensive downscales during rasterization.
    final targetDecodeWidth = (size.width * dpr * 2 / 2).round(); // keep <= 2x logical size
    final targetDecodeHeight = (size.height * dpr * 2 / 2).round();
    
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: _backgroundImagePath == null ? _backgroundColor : null,
        image: _backgroundImagePath != null
            ? DecorationImage(
                image: ResizeImage(
                  FileImage(File(_backgroundImagePath!)),
                  // Limit decode size to approximately the device pixel size of the preview
                  width: targetDecodeWidth,
                  height: targetDecodeHeight,
                  allowUpscaling: false,
                ),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
              )
            : null,
      ),
      child: Container(
        decoration: _backgroundImagePath != null
            ? BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
              )
            : null,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_textController.text.isNotEmpty) ...[
              Text(
                _textController.text,
                style: Theme.of(context).textTheme.bodyArabic.copyWith(
                  color: _textColor,
                  fontSize: _fontSize,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (_referenceController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _referenceController.text,
                  style: TextStyle(
                    color: _textColor.withValues(alpha: 0.8),
                    fontSize: _fontSize * 0.6,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else ...[
              Icon(
                Icons.text_fields,
                size: 64,
                color: _textColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Shkruani tekstin e ajetit për ta parë këtu',
                style: TextStyle(
                  color: _textColor.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String format, String label, IconData icon) {
    final isSelected = _selectedFormat == format;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (_) => setState(() => _selectedFormat = format),
    );
  }

  Widget _buildColorChip(Color color) {
    final isSelected = _backgroundColor == color;
    return GestureDetector(
      onTap: () => setState(() => _backgroundColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _buildTextColorChip(Color color) {
    final isSelected = _textColor == color;
    return GestureDetector(
      onTap: () => setState(() => _textColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color == Colors.white ? Colors.black : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  Size _getImageSize() {
    switch (_selectedFormat) {
      case 'square':
        return const Size(400, 400);
      case 'story':
        return const Size(300, 533); // 9:16 ratio
      case 'landscape':
        return const Size(533, 300); // 16:9 ratio
      default:
        return const Size(400, 400);
    }
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _backgroundImagePath = image.path;
      });
    }
  }

  Future<void> _generateImage() async {
    if (_isGenerating) return;
    
    setState(() => _isGenerating = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/kurani_ajet_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);

        if (mounted) {
          context.read<AppStateProvider>().enqueueSnack('Imazhi u ruajt në: ${file.path}');
        }
      }
    } catch (e) {
      if (mounted) {
        context.read<AppStateProvider>().enqueueSnack('Gabim në ruajtjen e imazhit: $e');
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareImage() async {
    if (_isGenerating) return;
    
    setState(() => _isGenerating = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes != null) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/kurani_ajet_share.png');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Ajet nga Kurani Fisnik\n\n${_textController.text}\n\n${_referenceController.text}',
        );
      }
    } catch (e) {
      if (mounted) {
        context.read<AppStateProvider>().enqueueSnack('Gabim në ndarjen e imazhit: $e');
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }
}

