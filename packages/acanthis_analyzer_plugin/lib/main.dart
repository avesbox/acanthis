import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/assists.dart';
import 'src/rules.dart';

final plugin = AcanthisPlugin();

class AcanthisPlugin extends Plugin {
  @override
  String get name => 'acanthis_analyzer_plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(AcanthisRules());
    registry.registerFixForRule(AcanthisRules.asyncCode, UseAsyncParse.new);
    registry.registerAssist(GenerateDto.new);
  }
}
