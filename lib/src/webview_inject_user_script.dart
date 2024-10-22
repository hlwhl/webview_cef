enum ScriptInjectTime { LOAD_START, LOAD_END }

class UserScript {
  final String script;
  final ScriptInjectTime injectTime;

  UserScript(this.script, this.injectTime);
}

class InjectUserScripts {
  List<UserScript> userScripts = [];

  void add(UserScript script) {
    userScripts.add(script);
  }

  List<UserScript> retrieveLoadStartInjectScripts() {
    return userScripts.where((e) => e.injectTime == ScriptInjectTime.LOAD_START).toList();
  }

  List<UserScript> retrieveLoadEndInjectScripts() {
    return userScripts.where((e) => e.injectTime == ScriptInjectTime.LOAD_END).toList();
  }
}