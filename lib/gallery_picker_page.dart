import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'photo_import.dart';

Future<List<AssetEntity>> pickGalleryPhotos(
  BuildContext context,
  DateTimeRange range,
) async {
  final selected = await Navigator.of(context).push<List<AssetEntity>>(
    MaterialPageRoute(builder: (context) => GalleryPickerPage(range: range)),
  );
  return selected ?? const [];
}

class GalleryPickerPage extends StatefulWidget {
  const GalleryPickerPage({required this.range, super.key});

  final DateTimeRange range;

  @override
  State<GalleryPickerPage> createState() => _GalleryPickerPageState();
}

class _GalleryPickerPageState extends State<GalleryPickerPage> {
  final Map<String, AssetEntity> _selected = {};
  List<AssetEntity> _assets = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await loadImagesInRange(widget.range);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '사진을 불러오지 못했습니다.';
      });
    }
  }

  void _toggle(AssetEntity asset) {
    setState(() {
      if (_selected.containsKey(asset.id)) {
        _selected.remove(asset.id);
      } else {
        _selected[asset.id] = asset;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _dayLabel(widget.range.start);
    final end = _dayLabel(widget.range.end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 선택'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.values.toList()),
            child: Text('완료 ${_selected.length}'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('$start ~ $end  사진을 여러 장 선택할 수 있습니다.'),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_assets.isEmpty) {
      return const Center(child: Text('이 기간의 사진이 없습니다.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        return _PhotoTile(
          asset: asset,
          selected: _selected.containsKey(asset.id),
          onTap: () => _toggle(asset),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Thumbnail(asset: asset),
          if (selected) ...[
            const ColoredBox(color: Color(0x66000000)),
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.check_circle, color: Colors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _dayLabel(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)}';
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({required this.asset});

  final AssetEntity asset;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  late final Future<Uint8List?> _bytes = widget.asset.thumbnailDataWithSize(
    const ThumbnailSize.square(240),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const ColoredBox(color: Color(0xFFE0E0E0));
        }
        return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
