import 'dart:io';

import 'package:settings_yaml/settings_yaml.dart';

class Settings {
  late SettingsYaml settingsFile;
  
  //late int maxTemperature; //celsius of course

  //Deck specific limits
  //late int minPowerLimit; //wats
  //late int maxPowerLimit; //safety :3, watts
  //late int powerLimitChangeStep; //wats
  //late int currentPowerLimit; //watts

  //ALL CPU CU Settings init
  late int maxAllCoreCurveOptimizer; //kurwas
  late int minAllCoreCurveOptimiser; //kurwas

  //Per Core CPU CU Settings init
  late int perCoreCurveOptimizerCoreCount; //Number of CPU Cores
  late List<dynamic> perCoreCurveOptimizerSets;

  //General CPU CU Settings init
  late int curveOptimizerType; //0 - All CPU, 1 - per core CPU
  late int curveOptimizerChangeStep; //kurwas

  //General settingsFile init
  late Duration delayTime;
  late bool isNotAllowedToRun;
  
  Settings init() {
    settingsFile = SettingsYaml.load(pathToSettings: '${File.fromUri(Platform.script).parent.path}/settings.yaml');

    //maxTemperature = settingsFile['temperatureLimit'] as int; //celsius of course

    //Deck specific limits
    //minPowerLimit = settingsFile['minPowerLimit'] as int; //wats
    //maxPowerLimit = settingsFile['maxPowerLimit'] as int; //safety :3, watts
    //powerLimitChangeStep = settingsFile['powerLimitChangeStep'] as int; //wats
    //currentPowerLimit = 15; //watts

    //ALL CPU CU Settings init
    maxAllCoreCurveOptimizer = settingsFile['maxAllCoreCurveOptimizer'] as int; //kurwas
    minAllCoreCurveOptimiser = settingsFile['minAllCoreCurveOptimizer'] as int; //kurwas

    //Per Core CPU CU Settings init
    perCoreCurveOptimizerCoreCount = settingsFile['perCoreCurveOptimizerCoreCount'] as int; //Number of CPU Cores
    perCoreCurveOptimizerSets = settingsFile['perCoreCurveOptimizerSets'] as List;

    //General CPU CU Settings init
    curveOptimizerType = settingsFile['curveOptimizerType'] as int; //0 - All CPU, 1 - per core CPU
    curveOptimizerChangeStep = settingsFile['curveOptimizerChangeStep'] as int; //kurwas

    //General settingsFile init
    delayTime = Duration(milliseconds: settingsFile['delay'] as int);
    isNotAllowedToRun = settingsFile['experimental'] as bool;
    return this;
  }
}