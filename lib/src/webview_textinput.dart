import 'dart:io';

import 'package:flutter/services.dart';

mixin WebeViewTextInput implements DeltaTextInputClient {
  @override
  TextEditingValue? currentTextEditingValue;

  @override
  AutofillScope? currentAutofillScope;

  TextInputConnection? _textInputConnection;

  bool _isKnownViewIdRace(PlatformException error) {
    final message = (error.message ?? '').toLowerCase();
    final isViewIdNull = message.contains('view id is null') ||
        message.contains('viewid is null');
    final isBadArguments = error.code == 'Bad Arguments';
    return isViewIdNull && isBadArguments;
  }

  attachTextInputClient() {
    try {
      _textInputConnection?.close();
      _textInputConnection = TextInput.attach(
        this,
        const TextInputConfiguration(enableDeltaModel: true),
      );
      if (!Platform.isWindows) {
        _textInputConnection?.show();
      }
    } on PlatformException catch (error) {
      // Flutter desktop text input can reject setClient when viewId is null
      // during fast focus changes. Ignore and keep browser alive.
      if (_isKnownViewIdRace(error)) {
        try {
          _textInputConnection?.close();
        } on PlatformException {
          // Ignore follow-up teardown errors while handling the same race.
        } finally {
          _textInputConnection = null;
        }
        return;
      }
      rethrow;
    }
  }

  detachTextInputClient() {
    try {
      _textInputConnection?.close();
    } on PlatformException catch (error) {
      // Ignore stale connection errors during teardown.
      if (!_isKnownViewIdRace(error)) {
        rethrow;
      }
    } finally {
      _textInputConnection = null;
    }
  }

  updateIMEComposionPosition(double x, double y, Offset offset) {
    /// 1.It always displays at the last position, which should be a bug in the Flutter engine.
    /// 2.If switch windows and switch back, this function can run well once.I think there must have a flush function called when switching windows
    /// 3.Windows can run well, but Linux can't.
    _textInputConnection?.setEditableSizeAndTransform(const Size(0, 0),
        Matrix4.translationValues(offset.dx + x, offset.dy + y, 0));
  }

  @override
  didChangeInputControl(
      TextInputControl? oldControl, TextInputControl? newControl) {
    print("changed");
  }

  @override
  connectionClosed() {}

  @override
  insertTextPlaceholder(Size size) {}

  @override
  insertContent(KeyboardInsertedContent content) {}

  @override
  performAction(TextInputAction action) {}

  @override
  performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  performSelector(String selectorName) {}

  @override
  removeTextPlaceholder() {}

  @override
  showAutocorrectionPromptRect(int start, int end) {}

  @override
  showToolbar() {}

  @override
  updateEditingValue(TextEditingValue value) {}

  @override
  updateFloatingCursor(RawFloatingCursorPoint point) {}
}
