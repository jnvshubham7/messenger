// Copyright © 2022-2023 IT ENGINEERING MANAGEMENT INC,
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
import 'package:messenger/themes.dart';
import 'package:messenger/ui/widget/widget_button.dart';

/// Swipeable widget allowing its [child] to be swiped to reveal [swipeable]
/// with a status next to it.
class SwipeableInfo extends StatelessWidget {
  const SwipeableInfo({
    super.key,
    required this.child,
    required this.swipeable,
    this.animation,
    this.asStack = false,
    this.isSent = false,
    this.isDelivered = false,
    this.isRead = false,
    this.isSending = false,
    this.isError = false,
    this.crossAxisAlignment = CrossAxisAlignment.end,
    this.padding = const EdgeInsets.only(bottom: 13),
    this.onPressed,
    this.expanded = false,
  });

  /// Expanded width of the [swipeable].
  static const double width = 85;

  /// Child to swipe to reveal [swipeable].
  final Widget child;

  /// Widget to display upon swipe.
  final Widget swipeable;

  final bool expanded;

  /// [AnimationController] controlling this widget.
  final AnimationController? animation;

  /// Indicator whether [swipeable] should be put in a [Stack] instead of a
  /// [Row].
  final bool asStack;

  /// Indicator whether status is sent.
  final bool isSent;

  /// Indicator whether status is delivered.
  final bool isDelivered;

  /// Indicator whether status is read.
  final bool isRead;

  final bool isSending;
  final bool isError;

  /// Position of a [swipeable] relatively to the [child].
  final CrossAxisAlignment crossAxisAlignment;

  /// Padding of a [swipeable].
  final EdgeInsetsGeometry padding;

  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    if (animation == null) {
      return child;
    }

    if (asStack) {
      return Stack(
        alignment: crossAxisAlignment == CrossAxisAlignment.end
            ? Alignment.bottomRight
            : Alignment.centerRight,
        children: [
          child,
          _animatedBuilder(
            Padding(
              padding: padding,
              child:
                  SizedBox(width: width, child: _swipeableWithStatus(context)),
            ),
          ),
        ],
      );
    }

    return _animatedBuilder(
      Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(child: child),
          Padding(
            padding: padding,
            child: SizedBox(width: width, child: _swipeableWithStatus(context)),
          ),
        ],
      ),
    );
  }

  /// Returns a [Row] of [swipeable] and a status.
  Widget _swipeableWithStatus(BuildContext context) {
    Style style = Theme.of(context).extension<Style>()!;
    return Transform.translate(
      offset: const Offset(0, 10),
      child: WidgetButton(
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: style.systemMessageStyle.copyWith(fontSize: 11),
          // style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
          child: Padding(
            // padding: EdgeInsets.zero,
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 3, 0, 3),
              margin: const EdgeInsets.only(right: 21),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: style.systemMessageBorder,
                color: Colors.white,
                // color: style.systemMessageColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF888888),
                    size: 15,
                  ),
                  const SizedBox(width: 3),
                  swipeable,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns an [AnimatedBuilder] with a [Transform.translate] transition.
  Widget _animatedBuilder(Widget child) => AnimatedBuilder(
        animation: animation!,
        builder: (context, child) {
          return Transform.translate(
            offset: Tween(
              begin: const Offset(width, 0),
              end: Offset.zero,
            ).evaluate(animation!),
            child: child,
          );
        },
        child: child,
      );
}
