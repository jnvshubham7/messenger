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

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:messenger/themes.dart';
import 'package:messenger/ui/page/home/page/chat/widget/back_button.dart';
import 'package:messenger/ui/page/home/widget/app_bar.dart';
import 'package:messenger/ui/page/home/widget/avatar.dart';
import 'package:messenger/ui/widget/progress_indicator.dart';
import 'package:messenger/ui/widget/svg/svg.dart';
import 'package:messenger/ui/widget/widget_button.dart';
import 'package:messenger/util/platform_utils.dart';

import '/domain/model/contact.dart';
import '/routes.dart';
import 'controller.dart';

// TODO: Implement [Routes.contacts] page.
/// View of the [Routes.contacts] page.
class ContactView extends StatelessWidget {
  const ContactView(this.id, {Key? key}) : super(key: key);

  /// ID of a [ChatContact] this [ContactView] represents.
  final ChatContactId id;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ContactController>(
      init: ContactController(id, Get.find()),
      tag: id.val,
      builder: (ContactController c) {
        final style = Theme.of(context).style;

        return Obx(() {
          if (c.status.value.isLoading) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CustomProgressIndicator()),
            );
          } else if (!c.status.value.isSuccess) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('No user found.')),
            );
          }

          return Scaffold(
            appBar: CustomAppBar(
              title: Row(
                children: [
                  Center(
                    child: AvatarWidget.fromRxContact(
                      c.contact.value,
                      radius: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.contact.value?.contact.value.name.val ?? '...',
                          ),
                          Obx(() {
                            // final subtitle = c.user?.user.value.getStatus();
                            const subtitle = 'Online';
                            return Text(
                              subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: const Color(0xFF888888)),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                ],
              ),
              padding: const EdgeInsets.only(left: 4, right: 20),
              leading: const [StyledBackButton()],
              actions: [
                WidgetButton(
                  onPressed: c.openChat,
                  child: Transform.translate(
                    offset: const Offset(0, 1),
                    child: const SvgIcon(SvgIcons.chat),
                  ),
                ),
                if (!context.isMobile) ...[
                  const SizedBox(width: 28),
                  WidgetButton(
                    onPressed: () => c.call(true),
                    child: const SvgIcon(SvgIcons.chatVideoCall),
                  ),
                ],
                const SizedBox(width: 28),
                WidgetButton(
                  onPressed: () => c.call(false),
                  child: const SvgIcon(SvgIcons.chatAudioCall),
                ),
              ],
            ),
            body: Obx(() {
              Widget block({
                List<Widget> children = const [],
                EdgeInsets padding = const EdgeInsets.fromLTRB(32, 16, 32, 16),
              }) {
                return Center(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      border: style.primaryBorder,
                      color: style.messageColor,
                      borderRadius: BorderRadius.circular(15),
                      // border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    constraints: context.isNarrow
                        ? null
                        : const BoxConstraints(maxWidth: 400),
                    padding: padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                );
              }

              return ListView(
                children: [
                  const SizedBox(height: 8),
                  block(
                    children: [
                      _label(context, 'Публичная информация'),
                      AvatarWidget.fromRxContact(
                        c.contact.value,
                        radius: 100,
                        badge: false,
                      ),
                      const SizedBox(height: 15),
                      // _name(c, context),
                    ],
                  ),
                  // block(
                  //   padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                  //   children: [_quick(c, context)],
                  // ),
                  block(
                    children: [
                      _label(context, 'Контактная информация'),
                      // _num(c, context),
                      // _emails(c, context),
                    ],
                  ),
                  block(
                    children: [
                      _label(context, 'Действия'),
                      // _actions(c, context),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
          );
        });
      },
    );
  }

  Widget _label(BuildContext context, String text) {
    final style = Theme.of(context).style;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: style.systemMessageStyle
                .copyWith(color: Colors.black, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
