import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

mixin WebeViewTextInput implements DeltaTextInputClient {
  @override
  TextEditingValue? currentTextEditingValue;

  @override
  AutofillScope? currentAutofillScope;

  TextInputConnection? _textInputConnection;

  attachTextInputClient() {
    // On Windows the OS IME is driven by the native WM_IME pipeline (the Flutter
    // text-input/delta path does not deliver composition for an OSR browser on
    // Windows). Don't claim the IME here so the native path can own it.
    if (Platform.isWindows) {
      return;
    }
    _textInputConnection?.close();
    _textInputConnection = TextInput.attach(
        this, const TextInputConfiguration(enableDeltaModel: true));
    // show() makes this connection the active IME target so the OS IME composes
    // into it and the framework emits composing deltas we relay to CEF.
    _textInputConnection?.show();
  }

  detachTextInputClient() {
    _textInputConnection?.close();
  }

  updateIMEComposionPosition(double x, double y, double height, Offset offset) {
    // Report a non-zero caret rectangle (height comes from the focused node /
    // composition bounds on the native side). A zero-area rect makes the engine
    // treat the region as non-composing and mis-positions the candidate window.
    final caretHeight = height > 0 ? height : 20.0;
    _textInputConnection?.setEditableSizeAndTransform(Size(1, caretHeight),
        Matrix4.translationValues(offset.dx + x, offset.dy + y, 0));
  }

  @override
  didChangeInputControl(
      TextInputControl? oldControl, TextInputControl? newControl) {
    debugPrint("changed");
  }

  @override
  connectionClosed() {}

  @override
  bool onFocusReceived() => false;

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
