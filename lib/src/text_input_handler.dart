import 'package:flutter/services.dart';

class MytextInput implements TextInputClient {
  @override
  void connectionClosed() {
    // TODO: implement connectionClosed
    print("close");
  }

  @override
  // TODO: implement currentAutofillScope
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  // TODO: implement currentTextEditingValue
  TextEditingValue? get currentTextEditingValue => throw UnimplementedError();

  @override
  void insertTextPlaceholder(Size size) {
    // TODO: implement insertTextPlaceholder
    print(size);
  }

  @override
  void performAction(TextInputAction action) {
    // TODO: implement performAction
    print(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // TODO: implement performPrivateCommand
    print(action);
  }

  @override
  void removeTextPlaceholder() {
    // TODO: implement removeTextPlaceholder
    print("remove");
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // TODO: implement showAutocorrectionPromptRect
    print(start);
  }

  @override
  void showToolbar() {
    // TODO: implement showToolbar
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    // TODO: implement updateEditingValue
    value.composing.start;
    value.composing.end;
    print(value.text);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // TODO: implement updateFloatingCursor
    print(point);
  }
}
