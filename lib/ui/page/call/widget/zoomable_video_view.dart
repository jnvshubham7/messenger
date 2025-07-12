// Copyright © 2022-2025 IT ENGINEERING MANAGEMENT INC,
//                       <https://github.com/team113>
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU Affero General Public License v3.0 as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License v3.0 for
// more details.
//
// You should have received a copy of the GNU Affero General Public License v3.0
// along with this program. If not, see
// <https://www.gnu.org/licenses/agpl-3.0.html>.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medea_jason/medea_jason.dart';

import '/domain/model/ongoing_call.dart';
import 'video_view.dart';

/// A zoomable wrapper around [RtcVideoView] that provides zoom and pan
/// functionality for screen sharing videos.
///
/// This widget uses [InteractiveViewer] to provide smooth zoom and pan
/// interactions that work across all platforms (mobile, desktop, and web).
class ZoomableVideoView extends StatefulWidget {
  const ZoomableVideoView({
    super.key,
    required this.renderer,
    this.source = MediaSourceKind.device,
    this.borderRadius,
    this.enableContextMenu = true,
    this.fit,
    this.border,
    this.respectAspectRatio = false,
    this.offstageUntilDetermined = false,
    this.onSizeDetermined,
    this.framelessBuilder,
    this.enableZoom = true,
    this.minScale = 1.0,
    this.maxScale = 5.0,
  });

  /// Renderer to display WebRTC video stream from.
  final RtcVideoRenderer renderer;

  /// [MediaSourceKind] of this video view.
  final MediaSourceKind source;

  /// [BoxFit] mode of this video.
  final BoxFit? fit;

  /// Border radius of this video.
  final BorderRadius? borderRadius;

  /// Builder building the background when the video's size is not determined.
  final Widget Function()? framelessBuilder;

  /// Indicator whether this video should take exactly the size of its
  /// [renderer]'s video stream.
  final bool respectAspectRatio;

  /// Indicator whether this video should be placed in an [Offstage] until its
  /// size is determined.
  final bool offstageUntilDetermined;

  /// Callback, called when the video's size is determined.
  final Function? onSizeDetermined;

  /// Indicator whether default context menu is enabled over this video or not.
  ///
  /// Only effective under the web, since only web has default context menu.
  final bool enableContextMenu;

  /// Optional border to apply to this video view.
  final Border? border;

  /// Whether zoom functionality is enabled.
  final bool enableZoom;

  /// Minimum scale factor for zooming.
  final double minScale;

  /// Maximum scale factor for zooming.
  final double maxScale;

  @override
  State<ZoomableVideoView> createState() => _ZoomableVideoViewState();
}

/// State of a [ZoomableVideoView] that manages zoom and pan interactions.
class _ZoomableVideoViewState extends State<ZoomableVideoView> {
  /// Controller for the [InteractiveViewer].
  final TransformationController _transformationController =
      TransformationController();

  /// Whether the view is currently being zoomed or panned.
  final RxBool _isInteracting = RxBool(false);

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // For non-screen sharing sources, return regular RtcVideoView
    if (!widget.enableZoom || widget.source != MediaSourceKind.display) {
      return RtcVideoView(
        widget.renderer,
        source: widget.source,
        borderRadius: widget.borderRadius,
        enableContextMenu: widget.enableContextMenu,
        fit: widget.fit,
        border: widget.border,
        respectAspectRatio: widget.respectAspectRatio,
        offstageUntilDetermined: widget.offstageUntilDetermined,
        onSizeDetermined: widget.onSizeDetermined,
        framelessBuilder: widget.framelessBuilder,
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        boundaryMargin: const EdgeInsets.all(0),
        constrained: false,
        scaleEnabled: true,
        panEnabled: true,
        onInteractionStart: (_) {
          _isInteracting.value = true;
        },
        onInteractionEnd: (_) {
          _isInteracting.value = false;
        },
        child: Container(
          decoration: BoxDecoration(
            border: widget.border,
            borderRadius: widget.borderRadius,
          ),
          child: RtcVideoView(
            widget.renderer,
            source: widget.source,
            enableContextMenu: widget.enableContextMenu,
            fit: widget.fit ?? BoxFit.contain,
            respectAspectRatio: widget.respectAspectRatio,
            offstageUntilDetermined: widget.offstageUntilDetermined,
            onSizeDetermined: widget.onSizeDetermined,
            framelessBuilder: widget.framelessBuilder,
          ),
        ),
      ),
    );
  }

  /// Resets the zoom and pan to the initial state.
  void resetTransformation() {
    _transformationController.value = Matrix4.identity();
  }

  /// Returns whether the view is currently being interacted with.
  bool get isInteracting => _isInteracting.value;
}
