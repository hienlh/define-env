import 'dart:convert';
import 'dart:io';

import 'package:define_env/src/config_writer/config_writer.dart';

/// [ConfigWriter] for VS Code.
///
/// This [ConfigWriter] takes the launch.json file, reads it and retains non dart-define arguments.
/// The new dart-define string generated from the .env file is appended to the retained arguments.
class VscodeConfigWriter extends ConfigWriter {
  /// [projectPath] is the path to VS Code project. It should contain the '.vscode/launch.json' file.
  /// [dartDefineString] is the dart-define string which is to be written to the config
  /// [configName] is the name of an existing configuration in launch.json. A config is not created if it is not found.
  VscodeConfigWriter({
    required String projectPath,
    required String dartDefineString,
    required String? configName,
    required String? programPath,
  }) : super(
          projectPath: projectPath,
          dartDefineString: dartDefineString,
          configName: configName,
          programPath: programPath,
        );

  @override
  List<File> getMandatoryFilesToUpdate() => [
        File(projectPath + "/.vscode/launch.json"),
      ];

  @override
  List<File> getOptionalFilesToUpdate() => [];

  @override
  String writeConfig(String fileContent) {
    /// launch.json usually contains comments, which is valid only in JSON5.
    /// At this point however we cannot preserve these comments.
    fileContent = fileContent.replaceAll(RegExp('.+//.+\n'), "");

    var configJson = jsonDecode(fileContent);

    var configList = (configJson['configurations'] as List);

    final configMap = configList.firstWhere(
        (config) => config['name'] == configName,
        orElse: () => null);

    var dartDefineList = getDartDefineList();

    if (configMap != null) {
      updateConfig(configMap, dartDefineList);
    } else {
      configList.add(createConfig(dartDefineList));
    }

    configJson['configurations'] = configList
        .map((configMap) => updateConfig(configMap, dartDefineList))
        .toList();

    return prettifyJson(configJson);
  }

  /// Update a single VS Code [config] with [dartDefineList].
  Map<String, dynamic> updateConfig(
    Map<String, dynamic> config,
    Iterable<String> dartDefineList,
  ) {
    if (config.containsKey('args')) {
      clearConfig(config);
      var args = config['args'] as List;
      args.addAll(dartDefineList);
    } else {
      config['args'] = dartDefineList.toList();
    }
    return config;
  }

  Map<String, dynamic> createConfig(
    Iterable<String> dartDefineList,
  ) {
    return {
      'name': configName,
      'request': 'launch',
      'type': 'dart',
      'program': programPath,
      'args': dartDefineList.toList(),
    };
  }

  /// Clear dart-define config
  Map<String, dynamic> clearConfig(Map<String, dynamic> config) {
    if (config.containsKey('args')) {
      var args = config['args'] as List;
      while (args.any((arg) => arg.startsWith('--dart-define'))) {
        final index = args.indexWhere((arg) => arg == '--dart-define');
        if (index >= 0) {
          args.removeRange(index, index + 2);
        } else {
          args.removeWhere((arg) => (arg as String).contains('--dart-define'));
        }
      }
    }
    return config;
  }

  /// Pretty Print [json]
  String prettifyJson(dynamic json) {
    var spaces = ' ' * 2;
    var encoder = JsonEncoder.withIndent(spaces);
    return encoder.convert(json);
  }

  /// Take [argList] and return only non dart define arguments from the list
  ///
  /// This is useful when you have arguments such as --profile or --release.
  List<dynamic> getNonDartDefineArguments(List<dynamic> argList) {
    bool previousWasDartDefine = false;

    List retainedArgs = [];
    argList.forEach((arg) {
      if (arg == '--dart-define') {
        previousWasDartDefine = true;
        return;
      }

      if (!previousWasDartDefine) {
        retainedArgs.add(arg);
      }

      previousWasDartDefine = false;
    });
    return retainedArgs;
  }

  /// Splits the dart-define string into a list format as required by VS Code.
  Iterable<String> getDartDefineList() {
    return (dartDefineString.split("--dart-define=")..removeAt(0))
        .expand((element) => ["--dart-define", element.trim()]);
  }
}
