// Copyright © 2022 IT ENGINEERING MANAGEMENT INC, <https://github.com/team113>
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
import 'package:messenger/domain/service/contact.dart';

import '../../../../../domain/repository/contact.dart';
import '/domain/model/contact.dart';

export 'view.dart';

/// Controller of the [Routes.contact] page.
class ContactController extends GetxController {
  ContactController(this.id, this._contactService);

  /// ID of a [ChatContact] this [ContactController] represents.
  final ChatContactId id;

  final Rx<RxChatContact?> contact = Rx(null);
  final Rx<RxStatus> status = Rx(RxStatus.empty());

  final ContactService _contactService;

  @override
  onInit() {
    _fetchContact();
    super.onInit();
  }

  void openChat() {}
  void call([bool withVideo = false]) {}

  void _fetchContact() async {
    status.value = RxStatus.loading();
    contact.value = _contactService.contacts[id];

    status.value =
        contact.value == null ? RxStatus.empty() : RxStatus.success();
  }
}
