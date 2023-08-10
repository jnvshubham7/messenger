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
import 'package:get/get.dart';
import 'package:messenger/domain/model/transaction.dart';
import 'package:messenger/l10n/l10n.dart';
import 'package:messenger/routes.dart';
import 'package:messenger/themes.dart';
import 'package:messenger/ui/page/home/tab/chats/widget/hovered_ink.dart';
import 'package:messenger/ui/page/home/widget/avatar.dart';
import 'package:messenger/ui/widget/svg/svg.dart';

enum TransactionCurrency { dollar, inter }

class TransactionWidget extends StatelessWidget {
  const TransactionWidget(
    this.transaction, {
    super.key,
    this.currency = TransactionCurrency.dollar,
  });

  final TransactionCurrency currency;
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).style;

    return Obx(() {
      final bool selected =
          router.route == '${Routes.transaction}/${transaction.id}';

      final Widget status;

      if (transaction is IncomingTransaction) {
        status = SvgImage.asset(
          'assets/icons/transaction_in.svg',
          width: 20,
          height: 20,
        );
      } else {
        status = SvgImage.asset(
          'assets/icons/transaction_out.svg',
          width: 20,
          height: 20,
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Container(
          constraints: const BoxConstraints(minHeight: 73),
          decoration: BoxDecoration(
            borderRadius: style.cardRadius,
            border: style.cardBorder,
            color: Colors.transparent,
          ),
          child: InkWellWithHover(
            borderRadius: style.cardRadius,
            selectedColor: style.colors.primary,
            unselectedColor: style.cardColor,
            onTap: () => router.transaction(transaction.id),
            selected: selected,
            hoveredBorder:
                selected ? style.primaryBorder : style.cardHoveredBorder,
            border: selected ? style.primaryBorder : style.cardBorder,
            unselectedHoverColor: style.cardColor.darken(0.03),
            selectedHoverColor: style.colors.primary,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  status,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    if (currency == TransactionCurrency.dollar)
                                      const TextSpan(text: '\$')
                                    else if (currency ==
                                        TransactionCurrency.inter)
                                      TextSpan(
                                        text: ' ¤',
                                        style: style.fonts.bodyLarge!.copyWith(
                                          color: selected ? Colors.white : null,
                                        ),
                                      ),
                                    const WidgetSpan(child: SizedBox(width: 1)),
                                    TextSpan(
                                      text: '${transaction.amount.abs()}',
                                    ),
                                  ],
                                  style: style.fonts.bodyLarge!.copyWith(
                                    color: selected ? Colors.white : null,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              transaction.at.short,
                              style: style.fonts.labelLarge?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : style.colors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'SWIFT transfer',
                                style: style.fonts.labelLarge?.copyWith(
                                  color: selected ? Colors.white : null,
                                ),
                              ),
                            ),
                            Text(
                              '${transaction.status.name.capitalizeFirst}',
                              style: style.fonts.labelLarge!.copyWith(
                                color: selected
                                    ? Colors.white
                                    : transaction.status ==
                                            TransactionStatus.failed
                                        ? Colors.red
                                        : style.colors.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
