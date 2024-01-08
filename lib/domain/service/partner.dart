// Copyright © 2022-2024 IT ENGINEERING MANAGEMENT INC,
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
import 'package:messenger/domain/model/transaction.dart';

import 'disposable_service.dart';

class PartnerService extends DisposableService {
  late final RxList<Transaction> transactions;

  late final RxDouble balance;

  @override
  void onInit() {
    transactions = RxList([
      IncomingTransaction(
        id: '428ac09a-6a85-4121-9c24-974d922156a0',
        amount: 100,
        at: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      IncomingTransaction(
        id: '428ac09a-6a85-4121-9c24-974d922156a1',
        amount: 100,
        at: DateTime.now().subtract(const Duration(days: 12)),
      ),
      OutgoingTransaction(
        id: '428ac09a-6a85-4121-9c24-974d922156a2',
        amount: -50,
        at: DateTime.now().subtract(const Duration(days: 20)),
      ),
      IncomingTransaction(
        id: '428ac09a-6a85-4121-9c24-974d922156a3',
        amount: 100,
        at: DateTime.now().subtract(const Duration(days: 50)),
      ),
    ]);

    balance = RxDouble(
      transactions.map((e) {
        if (e.status == TransactionStatus.completed) {
          return e.amount;
        }

        return 0;
      }).fold(0, (p, e) => p + e),
    );

    super.onInit();
  }

  void add(Transaction transaction) {
    transactions.add(transaction);
    transactions.sort((a, b) => b.at.compareTo(a.at));
    balance.value += transaction.amount;
  }
}
