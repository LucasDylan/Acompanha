import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PhotoPicker extends StatelessWidget {
  const PhotoPicker({
    super.key,
    required this.localPhotos,
    required this.existingUrls,
    required this.onPick,
    required this.onRemoveLocal,
    this.maxCount = 6,
  });

  final List<File> localPhotos;
  final List<String> existingUrls;
  final VoidCallback onPick;
  final void Function(int index) onRemoveLocal;
  final int maxCount;

  int get totalCount => localPhotos.length + existingUrls.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fotos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Text(
              '$totalCount/$maxCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: totalCount >= maxCount ? Colors.red : Colors.grey,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...existingUrls.asMap().entries.map((e) => _PhotoThumb(
                    image: e.value,
                    isNetwork: true,
                    onRemove: null,
                  )),
              ...localPhotos.asMap().entries.map((e) => _PhotoThumb(
                    file: e.value,
                    onRemove: () => onRemoveLocal(e.key),
                  )),
              if (totalCount < maxCount)
                _AddPhotoButton(onTap: onPick),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    this.file,
    this.image,
    this.isNetwork = false,
    this.onRemove,
  });

  final File? file;
  final String? image;
  final bool isNetwork;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 100,
              height: 100,
              child: isNetwork && image != null
                  ? CachedNetworkImage(
                      imageUrl: image!,
                      fit: BoxFit.cover,
                    )
                  : file != null
                      ? Image.file(file!, fit: BoxFit.cover)
                      : const SizedBox(),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Icon(Icons.add_photo_alternate, size: 36, color: Colors.grey.shade600),
      ),
    );
  }
}
