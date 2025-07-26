# Scroll Position Bug Fix Documentation

## Problem Description

**Issue**: In the Messenger Gapopa chat application, scroll positions are not preserved when navigating between chats. Every chat opens from the bottom (newest messages) instead of remembering where the user was previously scrolling.

**Requirements**:
1. Save scroll position when re-entering a chat
2. Do NOT save scroll position when closing the application (use in-memory storage only)
3. Test by running the application, not unit tests

## Root Cause Analysis

The issue was caused by:
1. **Controller Lifecycle**: The ChatController was being reused between different chats instead of being properly disposed
2. **Missing Save Triggers**: No mechanism to save scroll positions during user interactions
3. **Timing Issues**: Scroll positions were only attempted to be saved in `onClose()` which wasn't called consistently

## Solution Implementation

### 1. Data Structure for Scroll Positions

**File**: `lib/domain/service/chat.dart`

Added a new data class and in-memory storage:

```dart
/// Represents a saved scroll position in a chat.
class ChatScrollPosition {
  const ChatScrollPosition({
    required this.index,
    required this.offset,
  });

  /// The index of the item that was visible at the top of the scroll view.
  final int index;

  /// The offset within the item at [index].
  final double offset;
}

class ChatService extends DisposableService {
  // ... existing code ...

  /// In-memory storage for chat scroll positions.
  /// This is intentionally not persistent to meet the requirement that
  /// scroll positions should not be saved when closing the application.
  final Map<ChatId, ChatScrollPosition> _scrollPositions = {};

  /// Saves the scroll position for a specific chat.
  void saveScrollPosition(ChatId chatId, int index, double offset) {
    _scrollPositions[chatId] = ChatScrollPosition(index: index, offset: offset);
  }

  /// Retrieves the saved scroll position for a specific chat.
  ChatScrollPosition? getScrollPosition(ChatId chatId) {
    return _scrollPositions[chatId];
  }

  /// Clears the scroll position for a specific chat.
  void clearScrollPosition(ChatId chatId) {
    _scrollPositions.remove(chatId);
  }

  /// Clears all saved scroll positions.
  void clearAllScrollPositions() {
    _scrollPositions.clear();
  }
}
```

### 2. Save Scroll Position Logic

**File**: `lib/ui/page/home/page/chat/controller.dart`

#### A. Added Scroll Position Saving Method

```dart
/// Saves the current scroll position to [ChatService] for this chat.
void _saveCurrentScrollPosition() {
  if (chat?.id == null || elements.isEmpty || !listController.hasClients) {
    return;
  }

  final position = listController.position;
  if (!position.hasContentDimensions) {
    return;
  }

  // Calculate index based on current scroll position
  // Since the list is reversed, we need to handle this carefully
  final scrollFromBottom = position.maxScrollExtent - position.pixels;
  final itemHeight = position.maxScrollExtent / elements.length;
  final topIndex = (scrollFromBottom / itemHeight).floor();
  final offset = scrollFromBottom % itemHeight;
  
  final clampedIndex = topIndex.clamp(0, elements.length - 1);
  
  _chatService.saveScrollPosition(chat!.id, clampedIndex, offset);
}
```

#### B. Added Debounced Scroll Listener

Added a timer for debouncing and updated the scroll listener:

```dart
/// [Timer] for debouncing scroll position saves.
Timer? _scrollPositionSaveTimer;

/// Invokes [_updateSticky] and [_updateFabStates].
void _listControllerListener() {
  if (listController.hasClients) {
    _updateSticky();
    _updateFabStates();
    _loadMessages();
    
    // Debounce scroll position saving to avoid excessive saves
    _scrollPositionSaveTimer?.cancel();
    _scrollPositionSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveCurrentScrollPosition();
    });
  }
}
```

#### C. Save Position When Switching Chats

Modified the `_fetchChat()` method to save the previous chat's position:

```dart
Future<void> _fetchChat() async {
  // Save scroll position of previous chat before switching to new one
  if (chat != null && chat!.id != id) {
    _saveCurrentScrollPosition();
  }
  
  // ... rest of the method
}
```

### 3. Restore Scroll Position Logic

Updated the chat initialization to restore saved positions:

```dart
// In the chat initialization logic, check for saved position
final savedPosition = _chatService.getScrollPosition(chat!.id);
if (savedPosition != null) {
  // Use saved position
  listController.initIndex = savedPosition.index;
  listController.initOffset = savedPosition.offset;
} else {
  // Use calculated position (existing logic)
  final calculatedPosition = _calculateListViewIndex();
  listController.initIndex = calculatedPosition.index;
  listController.initOffset = calculatedPosition.offset;
}
```

### 4. Cleanup and Memory Management

Added proper cleanup in the `onClose()` method:

```dart
@override
void onClose() {
  // Save current scroll position before closing
  _saveCurrentScrollPosition();
  
  // Cancel the scroll position save timer
  _scrollPositionSaveTimer?.cancel();
  
  // ... existing cleanup code
}
```

## Technical Details

### FlutterListViewController Properties

The solution uses these key properties for scroll positioning:

- `initIndex`: The initial item index to display
- `initOffset`: The offset within the initial item  
- `reverse: true`: List is displayed in reverse order (newest at bottom)
- `initOffsetBasedOnBottom: true`: Offset calculation is from bottom

### Scroll Position Calculation

Since the chat list is reversed (newest messages at bottom), the calculation accounts for this:

```dart
final scrollFromBottom = position.maxScrollExtent - position.pixels;
final itemHeight = position.maxScrollExtent / elements.length;
final topIndex = (scrollFromBottom / itemHeight).floor();
final offset = scrollFromBottom % itemHeight;
```

### Debouncing Strategy

- **Trigger**: Save position 500ms after user stops scrolling
- **Purpose**: Prevents excessive saves during rapid scrolling
- **Implementation**: Timer-based debouncing in `_listControllerListener()`

## Testing Instructions

1. **Setup**: Run the application with the implemented changes
2. **Test Scroll Saving**:
   - Open a chat with many messages
   - Scroll up to see older messages (not at the bottom)
   - Wait 1 second for the position to save
3. **Test Position Restoration**:
   - Navigate to a different chat
   - Return to the first chat
   - Verify it opens at the previously scrolled position (not at bottom)
4. **Test Application Restart**:
   - Close and restart the application
   - Open any previously visited chat
   - Verify it opens at the bottom (positions not persisted across app restarts)

## Debug Console Output

When working correctly, you should see these console messages:

```
_fetchChat() called with id: [chatId], current chat: [previousChatId]
Switching from chat [previousChatId] to [chatId], saving scroll position
_saveCurrentScrollPosition called for chat: [previousChatId]
Saving scroll position for chat [previousChatId]: index=X, offset=Y
ChatService.saveScrollPosition called: chatId=[previousChatId], index=X, offset=Y
ScrollPositions now contains N entries
ChatService.getScrollPosition called for [chatId]: index=X, offset=Y
```

## Key Implementation Points

1. **In-Memory Only**: Uses `Map<ChatId, ChatScrollPosition>` that clears on app restart
2. **Multiple Save Triggers**: Saves on scroll (debounced), chat switch, and controller close
3. **Reverse List Handling**: Accounts for `reverse: true` in scroll calculations
4. **Performance Optimization**: 500ms debounce prevents excessive saving
5. **Graceful Fallback**: Falls back to calculated position if no saved position exists

## Performance Considerations

- **Memory Usage**: Minimal - only stores index/offset pairs per chat
- **CPU Impact**: Low - debounced saves prevent excessive calculations
- **Network Impact**: None - purely client-side functionality

## Troubleshooting

### If positions aren't being saved:
1. Check console for `_saveCurrentScrollPosition called` messages
2. Verify `_listControllerListener()` is being triggered
3. Ensure chat has sufficient content to scroll

### If positions aren't being restored:
1. Check console for `getScrollPosition called` messages  
2. Verify saved positions exist in the map
3. Ensure `initIndex` and `initOffset` are being set correctly

### If application crashes:
1. Check for null pointer exceptions in scroll calculations
2. Verify `listController.hasClients` before accessing position
3. Ensure `elements.isEmpty` check prevents division by zero

## Future Enhancements

1. **Persistence Option**: Add user setting to persist positions across app restarts
2. **Smart Cleanup**: Clear positions for chats not visited in X days
3. **Position Validation**: Verify saved positions are still valid when chat content changes
4. **User Preferences**: Allow users to disable scroll position saving
