import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

mixin WebeViewTextInput implements DeltaTextInputClient {
  @override
  TextEditingValue? currentTextEditingValue;

  @override
  AutofillScope? currentAutofillScope;

  TextInputConnection? _textInputConnection;

  void attachTextInputClient() {
    _textInputConnection?.close();
    _textInputConnection = TextInput.attach(
        this, const TextInputConfiguration(enableDeltaModel: true));
    if (!Platform.isWindows) {
      _textInputConnection?.show();
    }
    // _textInputConnection
  }

  void detachTextInputClient() {
    _textInputConnection?.close();
  }

  void updateIMEComposionPosition(double x, double y, Offset offset) {
    /// 1.It always displays at the last position, which should be a bug in the Flutter engine.
    /// 2.If switch windows and switch back, this function can run well once.I think there must have a flush function called when switching windows
    /// 3.Windows can run well, but Linux can't.
    _textInputConnection?.setEditableSizeAndTransform(const Size(0, 0),
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
