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

import 'dart:async';

import 'package:flutter/material.dart';

import '/domain/model/attachment.dart';
import '/l10n/l10n.dart';
import '/themes.dart';
import '/ui/widget/widget_button.dart';
import '/util/audio_utils.dart';
import '/util/message_popup.dart';

/// Audio player widget for audio file attachments.
class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget(this.attachment, {super.key, this.onPressed});

  /// [Attachment] to display as audio player.
  final Attachment attachment;

  /// Callback, called when this [AudioPlayerWidget] is pressed.
  final void Function()? onPressed;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

/// State of an [AudioPlayerWidget] maintaining audio playback state.
class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  /// Indicator whether this [AudioPlayerWidget] is hovered.
  bool _hovered = false;

  /// [StreamSubscription] for the audio playback state.
  StreamSubscription<AudioPlayerState>? _audioSubscription;

  /// Current audio player state.
  AudioPlayerState? _playerState;

  /// [AudioSource] for the current attachment.
  AudioSource? _audioSource;

  @override
  void initState() {
    super.initState();
    if (widget.attachment is FileAttachment) {
      (widget.attachment as FileAttachment).init();
    }
    _initializeAudioSource();
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    if (_audioSource != null) {
      AudioUtils.stopControllable(_audioSource!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).style;
    final Attachment e = widget.attachment;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovered
              ? style.colors.backgroundAuxiliaryLighter
              : style.colors.backgroundAuxiliary,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Play/Pause button
              WidgetButton(
                onPressed: _togglePlayPause,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hovered
                        ? style.colors.backgroundAuxiliaryLighter
                        : null,
                    border: Border.all(width: 2, color: style.colors.primary),
                  ),
                  child: Center(
                    child: Icon(
                      (_playerState?.isPlaying ?? false)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 24,
                      color: style.colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Audio info and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filename
                    Text(
                      e.filename,
                      style: style.fonts.medium.regular.onBackground,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Progress bar and time
                    Row(
                      children: [
                        // Progress bar
                        Expanded(
                          child: GestureDetector(
                            onTapDown: _onProgressBarTap,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: style.colors.onBackgroundOpacity13,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _getProgressFraction(),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: style.colors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Time display
                        Text(
                          _formatDuration(_playerState?.position ?? Duration.zero) +
                              ' / ' +
                              _formatDuration(_playerState?.duration ?? Duration.zero),
                          style: style.fonts.smaller.regular.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Download button
              if (e is FileAttachment) ...[
                const SizedBox(width: 12),
                WidgetButton(
                  onPressed: widget.onPressed,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.colors.onBackgroundOpacity7,
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: style.colors.onBackground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Initializes the audio source based on the attachment type.
  void _initializeAudioSource() {
    final attachment = widget.attachment;
    
    if (attachment is FileAttachment) {
      _audioSource = AudioSource.url(attachment.original.url);
    } else if (attachment is LocalAttachment) {
      if (attachment.file.path != null) {
        _audioSource = AudioSource.file(attachment.file.path!);
      } else {
        // For web or when path is not available, we can't play yet
        return;
      }
    }
  }

  /// Toggles play/pause state of the audio.
  void _togglePlayPause() {
    if (_audioSource == null) {
      MessagePopup.error('err_audio_source_unavailable'.l10n);
      return;
    }

    if (_playerState?.isPlaying ?? false) {
      // Pause
      AudioUtils.togglePlayPause(_audioSource!);
    } else {
      // Play - start playback and listen to state changes
      _audioSubscription?.cancel();
      _audioSubscription = AudioUtils.playControllable(_audioSource!).listen((state) {
        if (mounted) {
          setState(() {
            _playerState = state;
          });
        }
      });
    }
  }

  /// Handles tap on progress bar to seek to specific position.
  void _onProgressBarTap(TapDownDetails details) {
    if (_audioSource == null || _playerState == null) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final double progress = details.localPosition.dx / box.size.width;
    final Duration seekPosition = Duration(
      milliseconds: (progress * _playerState!.duration.inMilliseconds).round(),
    );
    
    AudioUtils.seekTo(_audioSource!, seekPosition);
  }

  /// Returns the progress fraction (0.0 to 1.0) for the progress bar.
  double _getProgressFraction() {
    if (_playerState == null) return 0.0;
    
    final duration = _playerState!.duration.inMilliseconds;
    final position = _playerState!.position.inMilliseconds;
    
    if (duration <= 0) return 0.0;
    
    return (position / duration).clamp(0.0, 1.0);
  }

  /// Formats duration as MM:SS.
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
