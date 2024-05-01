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

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' show visibleForTesting;
import 'package:get/get.dart';

import '../../provider/hive/my_user.dart';
import '/config.dart';
import '/domain/model/chat.dart';
import '/domain/model/fcm_registration_token.dart';
import '/domain/model/my_user.dart';
import '/domain/model/precise_date_time/precise_date_time.dart';
import '/domain/model/session.dart';
import '/domain/model/user.dart';
import '/domain/repository/auth.dart';
import '/provider/gql/exceptions.dart';
import '/provider/hive/account.dart';
import '/provider/hive/credentials.dart';
import '/routes.dart';
import '/util/log.dart';
import '/util/platform_utils.dart';
import '/util/web/web_utils.dart';

/// Authentication service exposing [credentials] of the authenticated session.
///
/// It contains all the required methods to do the authentication process and
/// exposes [credentials] (a session and an user) of the authorized session.
class AuthService extends GetxService {
  AuthService(
    this._authRepository,
    this._credentialsProvider,
    this._accountProvider,
  );

  /// Currently authorized session's [Credentials].
  final Rx<Credentials?> credentials = Rx(null);

  /// Authorization status.
  ///
  /// Can be:
  /// - `status.isEmpty` meaning that `MyUser` is unauthorized;
  /// - `status.isLoading` meaning that authorization data is being fetched
  ///   from storage;
  /// - `status.isLoadingMore` meaning that `MyUser` is authorized according to
  ///   the storage, but network request to the server is still in-flight;
  /// - `status.isSuccess` meaning successful authorization.
  final Rx<RxStatus> status = Rx<RxStatus>(RxStatus.loading());

  /// [CredentialsHiveProvider] used to store user [Session].
  final CredentialsHiveProvider _credentialsProvider;

  /// [AccountHiveProvider] storing the current user's [UserId].
  final AccountHiveProvider _accountProvider;

  /// Authorization repository containing required authentication methods.
  final AbstractAuthRepository _authRepository;

  /// Map of [Timer]s used to periodically check and refresh [Session]s of
  /// available accounts.
  final Map<UserId, Timer> _refreshTimers = {};

  /// Map, storing the [Credentials] of available accounts.
  ///
  /// If there's no [Credentials] for the given [UserId], then his [Credentials]
  /// should be considered as stale.
  final RxMap<UserId, Rx<Credentials>> allCredentials = RxMap();

  /// Puts the provided [creds] to [allCredentials].
  void _putCredentials(Credentials creds) {
    if (allCredentials.containsKey(creds.userId)) {
      allCredentials[creds.userId]?.value = creds;
    } else {
      allCredentials[creds.userId] = Rx(creds);
    }

    Log.debug(
      '_putCredentials($creds), result: ${allCredentials.keys}',
      '$runtimeType',
    );
  }

  /// [_refreshTimer] interval.
  final Duration _refreshTaskInterval = const Duration(seconds: 30);

  /// Minimal allowed [credentials] TTL.
  final Duration _accessTokenMinTtl = const Duration(minutes: 2);

  /// [StreamSubscription] to [CredentialsHiveProvider.boxEvents] saving new
  /// [Credentials] to the browser's storage.
  StreamSubscription? _credentialsSubscription;

  /// [StreamSubscription] to [WebUtils.onStorageChange] fetching new
  /// [Credentials].
  StreamSubscription? _storageSubscription;

  /// Returns the currently authorized [Credentials.userId].
  UserId? get userId => credentials.value?.userId;

  /// Indicates whether this [AuthService] is considered authorized.
  bool get _hasAuthorization => credentials.value != null;

  @override
  void onClose() {
    Log.debug('onClose()', '$runtimeType');

    _storageSubscription?.cancel();
    _credentialsSubscription?.cancel();
    _refreshTimers.forEach((_, t) => t.cancel());
    _refreshTimers.clear();
  }

  /// Initializes this service.
  ///
  /// Tries to load user data from the storage and navigates to the
  /// [Routes.auth] page if this operation fails. Otherwise, fetches user data
  /// from the server to be up-to-date with it.
  String? init() {
    Log.debug('init()', '$runtimeType');

    _authRepository.authExceptionHandler = (e) async {
      // Try to refresh session, otherwise just force logout.
      if (credentials.value?.refresh.expireAt
              .isAfter(PreciseDateTime.now().toUtc()) ==
          true) {
        await refreshSession();
      } else {
        _unauthorized();
        router.auth();
        throw e;
      }
    };

    // Listen to the [Credentials] changes to stay synchronized with another
    // tabs.
    _storageSubscription = WebUtils.onStorageChange.listen((e) {
      if (e.key?.startsWith('credentials_') ?? false) {
        Log.debug(
          '_storageSubscription(${e.key}): received a credentials update',
          '$runtimeType',
        );
        if (e.newValue != null) {
          final Credentials received =
              Credentials.fromJson(json.decode(e.newValue!));
          Credentials? current = credentials.value;
          final bool authorized = _hasAuthorization;

          if (received.userId == current?.userId) {
            // Check whether these [Credentials] are actually new.
            if (received.access.secret != current?.access.secret) {
              // These [Credentials] are of the active account, so just apply
              // them as saving to [Hive] has already been performed by another
              // tab.
              _authRepository.token = received.access.secret;
              _authRepository.applyToken();
              credentials.value = received;
              _putCredentials(received);
              status.value = RxStatus.success();

              if (!authorized) {
                router.home();
              }
            }
          } else if (!authorized) {
            _authorized(received);
            status.value = RxStatus.success();
          } else {
            current = allCredentials[received.userId]?.value;
            if (current == null ||
                received.access.secret != current.access.secret) {
              // These [Credentials] are of another account, so just save them.
              _putCredentials(received);
            }
          }
        } else {
          final UserId? userId = allCredentials.keys
              .firstWhereOrNull((k) => e.key?.endsWith(k.val) ?? false);

          allCredentials.remove(userId);

          final bool currentAreNull = credentials.value == null;
          final bool currentDeleted =
              userId != null && userId == credentials.value?.userId;

          if ((currentAreNull || currentDeleted) && !WebUtils.isPopup) {
            router.go(_unauthorized());
          }
        }
      }
    });

    _credentialsSubscription = _credentialsProvider.boxEvents.listen((e) {
      Log.debug(
        '_credentialsSubscription event deleted: ${e.deleted}, ${e.key}',
        '$runtimeType',
      );
      if (e.deleted) {
        WebUtils.removeCredentials(UserId(e.key as String));
      } else {
        WebUtils.putCredentials(e.value);
      }
    });

    final UserId? userId = _accountProvider.userId;
    final Credentials? creds =
        userId != null ? _credentialsProvider.get(userId) : null;

    if (creds == null) {
      return _unauthorized();
    }

    for (final Credentials e in _credentialsProvider.valuesSafe) {
      WebUtils.putCredentials(e);
      _putCredentials(e);
    }

    final AccessToken access = creds.access;
    final RefreshToken refresh = creds.refresh;

    if (access.expireAt.isAfter(PreciseDateTime.now().toUtc())) {
      _authorized(creds);
      status.value = RxStatus.success();
      return null;
    } else if (refresh.expireAt.isAfter(PreciseDateTime.now().toUtc())) {
      _authorized(creds);
      if (_shouldRefresh(creds)) {
        refreshSession();
      }
      status.value = RxStatus.success();
      return null;
    } else {
      // Neither [AccessToken] nor [RefreshToken] are valid, should logout.
      return _unauthorized();
    }
  }

  /// Returns authorization status of the [MyUser] identified by the provided
  /// [UserId].
  ///
  /// Returns authorization status of active [MyUser] if [userId] is not
  /// provided.
  bool isAuthorized([UserId? userId]) {
    if (userId == null || userId == credentials.value?.userId) {
      return _hasAuthorization;
    }

    return allCredentials[userId]?.value != null;
  }

  /// Initiates password recovery for a [MyUser] identified by the provided
  /// [num]/[login]/[email]/[phone] (exactly one of fourth should be specified).
  ///
  /// Sends a recovery [ConfirmationCode] to [MyUser]'s [email] and [phone].
  ///
  /// If [MyUser] has no password yet, then this method still may be used for
  /// recovering his sign-in capability.
  ///
  /// The number of generated [ConfirmationCode]s is limited up to 10 per 1
  /// hour.
  Future<void> recoverUserPassword({
    UserLogin? login,
    UserNum? num,
    UserEmail? email,
    UserPhone? phone,
  }) async {
    Log.debug(
      'recoverUserPassword(login: $login, num: $num, email: ***, phone: ***)',
      '$runtimeType',
    );

    await _authRepository.recoverUserPassword(
      login: login,
      num: num,
      email: email,
      phone: phone,
    );
  }

  /// Validates the provided password recovery [ConfirmationCode] for a [MyUser]
  /// identified by the provided [num]/[login]/[email]/[phone] (exactly one of
  /// fourth should be specified).
  Future<void> validateUserPasswordRecoveryCode({
    required ConfirmationCode code,
    UserLogin? login,
    UserNum? num,
    UserEmail? email,
    UserPhone? phone,
  }) async {
    Log.debug(
      'validateUserPasswordRecoveryCode(code: $code, login: $login, num: $num, email: ***, phone: ***)',
      '$runtimeType',
    );

    await _authRepository.validateUserPasswordRecoveryCode(
      login: login,
      num: num,
      email: email,
      phone: phone,
      code: code,
    );
  }

  /// Resets password for a [MyUser] identified by the provided
  /// [num]/[login]/[email]/[phone] (exactly one of fourth should be specified)
  /// and recovery [ConfirmationCode].
  ///
  /// If [MyUser] has no password yet, then [newPassword] will be his first
  /// password unlocking the sign-in capability.
  Future<void> resetUserPassword({
    required ConfirmationCode code,
    required UserPassword newPassword,
    UserLogin? login,
    UserNum? num,
    UserEmail? email,
    UserPhone? phone,
  }) async {
    Log.debug(
      'resetUserPassword(code: $code, newPassword: ***, login: $login, num: $num, email: ***, phone: ***)',
      '$runtimeType',
    );

    await _authRepository.resetUserPassword(
      login: login,
      num: num,
      email: email,
      phone: phone,
      code: code,
      newPassword: newPassword,
    );
  }

  /// Creates a new [MyUser] having only [UserId] and [UserNum] fields, and
  /// creates a new [Session] for this [MyUser] (valid for 24 hours).
  ///
  /// Once the created [Session] expires, the created [MyUser] looses access, if
  /// he doesn't re-sign in within that period of time.
  ///
  /// If [status] is already authorized, then this method does nothing, however
  /// this logic can be ignored by specifying either [switching] as `true`.
  Future<void> register({
    bool switching = false,
  }) async {
    Log.debug('register(switching: $switching)', '$runtimeType');

    status.value = switching ? RxStatus.loadingMore() : RxStatus.loading();

    await WebUtils.protect(() async {
      // If service is already authorized, then no-op, as this operation is
      // meant to be invoked only during unauthorized phase or account
      // switching, or otherwise the dependencies will be broken as of now.
      if (!switching && _hasAuthorization) {
        return;
      }

      try {
        final Credentials data = await _authRepository.signUp();
        _authorized(data);
        status.value = RxStatus.success();
      } catch (e) {
        if (switching) {
          status.value = RxStatus.success();
        } else {
          _unauthorized();
        }
        rethrow;
      }
    });
  }

  /// Sends a [ConfirmationCode] to the provided [email] for signing up with it.
  ///
  /// [ConfirmationCode] is sent to the [email], which should be confirmed with
  /// [confirmSignUpEmail] in order to successfully sign up.
  ///
  /// [ConfirmationCode] sent can be resent with [resendSignUpEmail].
  Future<void> signUpWithEmail(UserEmail email) async {
    Log.debug('signUpWithEmail(***)', '$runtimeType');
    await _authRepository.signUpWithEmail(email);
  }

  /// Confirms the [signUpWithEmail] with the provided [ConfirmationCode].
  ///
  /// If [status] is already authorized, then this method does nothing.
  Future<void> confirmSignUpEmail(
    ConfirmationCode code, {
    bool switching = false,
  }) async {
    Log.debug(
      'confirmSignUpEmail($code, switching: $switching)',
      '$runtimeType',
    );

    status.value = switching ? RxStatus.loadingMore() : RxStatus.loading();

    await WebUtils.protect(() async {
      // If service is already authorized, then no-op, as this operation is
      // meant to be invoked only during unauthorized phase, or otherwise the
      // dependencies will be broken as of now.
      if (!switching && _hasAuthorization) {
        return;
      }

      try {
        final Credentials data = await _authRepository.confirmSignUpEmail(code);
        _authorized(data);
        status.value = RxStatus.success();
      } catch (e) {
        if (switching) {
          status.value = RxStatus.success();
        } else {
          _unauthorized();
        }

        rethrow;
      }
    });
  }

  /// Resends a new [ConfirmationCode] to the [UserEmail] specified in
  /// [signUpWithEmail].
  Future<void> resendSignUpEmail() async {
    Log.debug('resendSignUpEmail()', '$runtimeType');
    await _authRepository.resendSignUpEmail();
  }

  /// Creates a new [Session] for the [MyUser] identified by the provided
  /// [num]/[login]/[email]/[phone] (exactly one of four should be specified).
  ///
  /// The created [Session] expires in 1 day after creation.
  ///
  /// Throws [CreateSessionException].
  ///
  /// If [status] is already authorized, then this method does nothing, however
  /// this logic can be ignored by specifying either [force] or [switching] as
  /// `true`. But be careful, [force] set to `true` also ignores possible
  /// [WebUtils.protect] races - you may want to lock it before invoking this
  /// method to be async-safe.
  Future<void> signIn(
    UserPassword password, {
    UserLogin? login,
    UserNum? num,
    UserEmail? email,
    UserPhone? phone,
    bool force = false,
    bool switching = false,
  }) async {
    Log.debug(
      'signIn(***, login: $login, num: $num, email: ***, phone: ***, force: $force, switching: $switching)',
      '$runtimeType',
    );

    // If [force] is `true`, then [WebUtils.protect] is ignored.
    final Function protect = force ? (fn) => fn() : WebUtils.protect;

    status.value =
        switching || force ? RxStatus.loadingMore() : RxStatus.loading();
    await protect(() async {
      // If service is already authorized, then no-op, as this operation is
      // meant to be invoked only during unauthorized phase or to sign in to a
      // new account , or otherwise the dependencies will be broken as of now.
      if (!force && !switching && _hasAuthorization) {
        return;
      }

      try {
        final Credentials creds = await _authRepository.signIn(
          password,
          login: login,
          num: num,
          email: email,
          phone: phone,
        );
        _authorized(creds);
        status.value = RxStatus.success();
      } catch (e) {
        if (switching) {
          status.value = RxStatus.success();
        } else {
          _unauthorized();
        }

        rethrow;
      }
    });
  }

  /// Authorizes the current [Session] from the provided [credentials].
  @visibleForTesting
  Future<void> signInWith(Credentials credentials) async {
    Log.debug('signInWith(credentials)', '$runtimeType');

    // Check if the [credentials] are valid.
    credentials =
        await _authRepository.refreshSession(credentials.refresh.secret);

    status.value = RxStatus.loadingMore();
    await WebUtils.protect(() async {
      _authorized(credentials);
      status.value = RxStatus.success();
    });
  }

  /// Deletes [Session] of the active [MyUser].
  ///
  /// Returns the path of the authentication page.
  ///
  /// If [force] is `true`, then the current [Credentials] will be revoked
  /// unilaterally and immediately.
  Future<String> deleteSession({bool force = false}) async {
    Log.debug('deleteSession(force: $force)', '$runtimeType');

    status.value = RxStatus.empty();

    if (force) {
      if (userId != null) {
        _authRepository.removeAccount(userId!);
      }

      return _unauthorized();
    }

    return await WebUtils.protect(() async {
      try {
        FcmRegistrationToken? fcmToken;

        if (PlatformUtils.pushNotifications) {
          final NotificationSettings settings =
              await FirebaseMessaging.instance.getNotificationSettings();

          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
            final String? token = await FirebaseMessaging.instance.getToken(
              vapidKey: Config.vapidKey,
            );

            if (token != null) {
              fcmToken = FcmRegistrationToken(token);
            }
          }
        }

        await _authRepository.deleteSession(fcmToken);
      } catch (e) {
        printError(info: e.toString());
      }

      return _unauthorized();
    });
  }

  /// Deletes [Session] of the active [MyUser] and removes it from the list of
  /// available accounts.
  ///
  /// Returns the path of the authentication page.
  Future<String> logout() async {
    Log.debug('logout()', '$runtimeType');

    if (userId != null) {
      _authRepository.removeAccount(userId!);
    }

    return await deleteSession();
  }

  /// Switches to the account with the provided [UserId] using the persisted
  /// [Credentials].
  ///
  /// Returns `true` if the account was successfully switched, otherwise returns
  /// `false`.
  Future<bool> switchAccount(UserId userId) async {
    Log.debug('switchAccount($userId)', '$runtimeType');

    final Credentials? creds = allCredentials[userId]?.value;
    if (creds == null) {
      return false;
    }

    status.value = RxStatus.loading();

    try {
      if (_shouldRefresh(creds)) {
        await refreshSession();
      }

      final Credentials? freshCredentials = allCredentials[userId]?.value;
      if (freshCredentials == null) {
        return false;
      }

      // TODO: This workarounds the situation when the password for another
      //       account was changed or the account was deleted. We should have a
      //       remote subscription to [MyUser] events for each of the accounts.
      final bool areValid = await validateToken(freshCredentials);
      if (areValid) {
        await WebUtils.protect(() async {
          _authorized(freshCredentials);
          status.value = RxStatus.success();
        });

        return true;
      }
    } catch (_) {
      status.value = RxStatus.success();
      rethrow;
    }

    return false;
  }

  /// Deletes the [MyUser] identified by the provided [id] from the accounts.
  Future<void> removeAccount(UserId id) async {
    Log.debug('removeAccount($id)', '$runtimeType');
    await _authRepository.removeAccount(id);
  }

  /// Validates the [AccessToken] of the provided [Credentials].
  ///
  /// If none provided, checks the current [credentials].
  Future<bool> validateToken([Credentials? creds]) async {
    // If [creds] are not provided, then validate the current [credentials].
    creds ??= credentials.value;

    Log.debug('validateToken($creds)', '$runtimeType');

    if (creds == null) {
      return false;
    }

    return await WebUtils.protect(() async {
      try {
        await _authRepository.validateToken(creds!);
        return true;
      } on AuthorizationException {
        return false;
      }
    });
  }

  /// Refreshes [Credentials] of the account with the provided [UserId] or of
  /// the active one, if [userId] is not provided.
  Future<void> refreshSession({UserId? userId}) async {
    final FutureOr<bool> futureOrBool = WebUtils.isLocked;
    final bool isLocked =
        futureOrBool is bool ? futureOrBool : await futureOrBool;

    userId ??= this.userId;
    final bool areCurrent = userId == this.userId;

    final provider = Get.find<MyUserHiveProvider>();
    final myUser = userId != null ? provider.get(userId)?.value : null;
    final name = myUser?.name ?? myUser?.num ?? userId;

    Log.debug(
      'refreshSession($name) with `isLocked`: $isLocked',
      '$runtimeType',
    );

    try {
      // Wait for the lock to be released and check the [Credentials] again as
      // some other task may have already refreshed them.
      await WebUtils.protect(() async {
        final Credentials? oldCreds = allCredentials[userId]?.value;

        if (isLocked) {
          Log.debug(
            'refreshSession($name): acquired the lock, while it was locked, thus should proceed: ${_shouldRefresh(oldCreds)}',
            '$runtimeType',
          );

          if (!_shouldRefresh(oldCreds)) {
            // [Credentials] are fresh.
            return;
          }
        } else {
          Log.debug(
            'refreshSession($name): acquired the lock, while it was unlocked',
            '$runtimeType',
          );
        }

        if (oldCreds == null) {
          // These [Credentials] were removed while we've been waiting for the
          // lock to be released.
          if (areCurrent) {
            router.go(_unauthorized());
          }
          return;
        }

        // Fetch the fresh [Credentials] from browser's storage, if there are
        // any.
        final Credentials? webStoredCreds =
            WebUtils.getCredentials(oldCreds.userId);

        if (webStoredCreds != null &&
            webStoredCreds.access.secret != oldCreds.access.secret) {
          if (areCurrent) {
            _authorized(webStoredCreds);
            status.value = RxStatus.success();
          } else {
            // [Credentials] of another account were refreshed.
            _putCredentials(webStoredCreds);
          }
          return;
        }

        try {
          final Credentials data = await _authRepository.refreshSession(
            oldCreds.refresh.secret,
            raw: !areCurrent,
          );

          if (areCurrent) {
            _authorized(data);
          } else {
            // [Credentials] of not currently active account were updated,
            // just save them.
            //
            // Saving to [Hive] is safe here, as this callback is guarded by
            // the [WebUtils.protect] lock.
            await _credentialsProvider.put(data);
            _putCredentials(data);
          }
          status.value = RxStatus.success();
        } on RefreshSessionException catch (_) {
          Log.debug(
            'refreshSession($name): RefreshSessionException occurred, removing credentials'
            '$runtimeType',
          );

          if (areCurrent) {
            router.go(_unauthorized());
          } else {
            // Remove stale [Credentials].
            _credentialsProvider.remove(oldCreds.userId);
            allCredentials.remove(oldCreds.userId);
          }

          rethrow;
        }
      });
    } on RefreshSessionException catch (_) {
      // No-op, already handled in the callback passed to [WebUtils.protect].
    } catch (e) {
      Log.debug(
        'refreshSession($name): Exception occurred: $e',
        '$runtimeType',
      );

      // If any unexpected exception happens, just retry the mutation.
      await Future.delayed(const Duration(seconds: 2));
      await refreshSession(userId: userId);
    }
  }

  /// Uses the specified [ChatDirectLink] by the authenticated [MyUser] creating
  /// a new [Chat]-dialog or joining an existing [Chat]-group.
  Future<ChatId> useChatDirectLink(ChatDirectLinkSlug slug) async {
    Log.debug('useChatDirectLink($slug)', '$runtimeType');
    return await _authRepository.useChatDirectLink(slug);
  }

  /// Initializes the refresh timers for all the authenticated [MyUser]s.
  void _initRefreshTimers() {
    Log.debug('_initRefreshTimers()', '$runtimeType');

    _refreshTimers.forEach((_, t) => t.cancel());
    _refreshTimers.clear();

    for (final UserId id in allCredentials.keys) {
      _refreshTimers[id] = Timer.periodic(
        _refreshTaskInterval,
        (_) {
          final Credentials? creds = allCredentials[id]?.value;
          if (creds == null) {
            Log.debug(
              '_initRefreshTimers(): no credentials found for user $id, killing timer',
              '$runtimeType',
            );

            // Cancel the timer to avoid memory leaks.
            _refreshTimers.remove(id)?.cancel();
            return;
          }

          if (_shouldRefresh(creds)) {
            refreshSession(userId: id);
          }
        },
      );
    }
  }

  /// Sets authorized [status] to `isLoadingMore` (aka "partly authorized").
  void _authorized(Credentials creds) {
    Log.debug('_authorized($creds)', '$runtimeType');

    _credentialsProvider.put(creds);
    _accountProvider.set(creds.userId);

    _authRepository.token = creds.access.secret;
    credentials.value = creds;
    _putCredentials(creds);

    _initRefreshTimers();

    status.value = RxStatus.loadingMore();
  }

  /// Sets authorized [status] to `isEmpty` (aka "unauthorized").
  String _unauthorized() {
    Log.debug('_unauthorized()', '$runtimeType');

    final UserId? id = userId;
    if (id != null) {
      _credentialsProvider.remove(id);
      _refreshTimers.remove(id)?.cancel();
      allCredentials.remove(id);
    }

    if (id == _accountProvider.userId) {
      // TODO: This workaounds the situation when another tab on Web has already
      //       rewritten the value in [_accountProvider] during switching to
      //       another account but the tab this code is running on still uses
      //       the [credentials] of an old one, which is an expected behavior.
      _accountProvider.clear();
    }

    _authRepository.token = null;
    credentials.value = null;
    status.value = RxStatus.empty();

    return Routes.auth;
  }

  /// Indicates whether the [credentials] require a refresh.
  ///
  /// If [credentials] are not provided, then ones of the current session are
  /// checked.
  bool _shouldRefresh([Credentials? credentials]) {
    final Credentials? creds = credentials ?? this.credentials.value;

    return creds?.access.expireAt
            .subtract(_accessTokenMinTtl)
            .isBefore(PreciseDateTime.now().toUtc()) ??
        false;
  }
}
