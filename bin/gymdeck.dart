import 'dart:io';
import 'dart:math';
import 'package:gymdeck/ryzenadj.dart';
import 'package:gymdeck/sysres/base.dart';
import 'package:settings_yaml/settings_yaml.dart';


void main() async {
  await SystemResources.init(); //init cpuLoadAverage module

  var settings = SettingsYaml.load(pathToSettings: '${File.fromUri(Platform.script).parent.path}/settings.yaml');

  //int maxTemperature = settings['temperatureLimit'] as int; //celsius of course

  //Deck specific limits
  //int minPowerLimit = settings['minPowerLimit'] as int; //wats
  //int maxPowerLimit = settings['maxPowerLimit'] as int; //safety :3, watts

  //ALL CPU CU Settings init
  int maxAllCoreCurveOptimizer = settings['maxAllCoreCurveOptimizer'] as int; //kurwas
  int minAllCoreCurveOptimiser = settings['minAllCoreCurveOptimizer'] as int; //kurwas

  //Per Core CPU CU Settings init
  int perCoreCurveOptimizerCoreCount = settings['perCoreCurveOptimizerCoreCount'] as int; //Number of CPU Cores
  List<dynamic> perCoreCurveOptimizerSets = settings['perCoreCurveOptimizerSets'] as List;

  //General CPU CU Settings init
  int curveOptimizerType = settings['curveOptimizerType'] as int; //0 - All CPU, 1 - per core CPU
  int curveOptimizerChangeStep = settings['curveOptimizerChangeStep'] as int; //kurwas

  //int powerLimitChangeStep = settings['powerLimitChangeStep'] as int; //wats
  //int currentPowerLimit = 15; //watts
  int previousCurveOptimizer = 0; //kurwas
  List<int> perCorePreviousCurveOptimizer = List.filled(perCoreCurveOptimizerCoreCount, 0); // kurwas per core
  int prevCpuLoadAverage = -1; //percents
  List<int> perCorePreviousCpuLoadAverage = List.filled(perCoreCurveOptimizerCoreCount, -1); // percents per core
  while (true) {
    String temperatureFileContent = File('/sys/class/thermal/thermal_zone0/temp').readAsStringSync();
    int temperature = int.parse(temperatureFileContent) ~/ 1000;
    int cpuLoadAverage = (SystemResources.cpuLoadAvg() * 100).toInt();

    //Process TDP works
    //currentPowerLimit = processTDP(temperature, cpuLoadAverage, maxTemperature, currentPowerLimit, minPowerLimit, maxPowerLimit, powerLimitChangeStep);
    if (curveOptimizerType == 1) {
      for (int i = 0; i < perCoreCurveOptimizerCoreCount; i++){
        (prevCpuLoadAverage, previousCurveOptimizer) = processCO(
            temperature,
            cpuLoadAverage,
            perCoreCurveOptimizerSets[i]['max'],
            curveOptimizerChangeStep,
            perCorePreviousCurveOptimizer[i],
            perCorePreviousCpuLoadAverage[i],
            perCoreCurveOptimizerSets[i]['min'],
            true,
            i);
        perCorePreviousCurveOptimizer[i] = previousCurveOptimizer;
        perCorePreviousCpuLoadAverage[i] = prevCpuLoadAverage;
      }
    } else {
      (prevCpuLoadAverage, previousCurveOptimizer) = processCO(
          temperature,
          cpuLoadAverage,
          maxAllCoreCurveOptimizer,
          curveOptimizerChangeStep,
          previousCurveOptimizer,
          prevCpuLoadAverage,
          minAllCoreCurveOptimiser,
          false,
          0);
    }
    sleep(Duration(milliseconds: settings['delay'] as int));
  }

}

int processTDP(int temperature, int cpuLoadAverage, int maxTemperature, int currentPowerLimit, int minPowerLimit, int maxPowerLimit, int powerLimitChangeStep) {
  int newPowerLimit = currentPowerLimit;
  if (temperature >= maxTemperature - 2) {
    newPowerLimit =
        max(minPowerLimit, newPowerLimit - powerLimitChangeStep);
  } //too high temp, reducing
  else if (cpuLoadAverage > 10 && temperature <= maxTemperature - 5) {
    newPowerLimit =
        min(maxPowerLimit, newPowerLimit + powerLimitChangeStep);
  } //too high load, not too hot, why not to BURN YOUR DECK?!

  if (currentPowerLimit != newPowerLimit) {
    int tdp = newPowerLimit * 1000;
    print('$newPowerLimit $temperature $cpuLoadAverage');
    RyzenAdjWrapper.applyPowerSettings(tdp, maxTemperature);
    return newPowerLimit;
  }
  return currentPowerLimit;
}



(int, int) processCO(int temperature, int cpuLoadAverage, int maxCurveOptimizer, int curveOptimizerChangeStep, int previousCurveOptimizer, int prevCpuLoadAverage, int minCurveOptimiser, bool isPerCore, int core) {
    int newMaxCO = maxCurveOptimizer;
    int newCO = 0;
    // Change max CO limit based on CPU usage
    if (cpuLoadAverage < 10) {
      newMaxCO = maxCurveOptimizer;
    }
    else if (cpuLoadAverage >= 10 && cpuLoadAverage < 80) {
      newMaxCO = maxCurveOptimizer - curveOptimizerChangeStep * 2;
    }
    else if (cpuLoadAverage >= 80) {
      newMaxCO = maxCurveOptimizer;
    }

    if (previousCurveOptimizer == 0 && prevCpuLoadAverage <= 0) previousCurveOptimizer = newMaxCO;
    if (prevCpuLoadAverage < 0) prevCpuLoadAverage = 100;

    // Increase CO if the CPU load is increased by 10
    if (cpuLoadAverage > prevCpuLoadAverage + 10)
    {
      newCO = previousCurveOptimizer + curveOptimizerChangeStep;

      // Store the current CPU load for the next iteration
      prevCpuLoadAverage = prevCpuLoadAverage + 10;
    }
    // Decrease CO if the CPU load is decreased by 10
    else if (cpuLoadAverage < prevCpuLoadAverage - 10)
    {
      newCO = previousCurveOptimizer - curveOptimizerChangeStep;

      // Store the current CPU load for the next iteration
      prevCpuLoadAverage = prevCpuLoadAverage - 10;
    }

    // Make sure min and max CO is not exceeded
    if (newCO <= minCurveOptimiser) newCO = minCurveOptimiser;
    if (newCO >= newMaxCO) newCO = newMaxCO;

    // Make sure CO is within CO max limit + 5
    if (newCO > 55) newCO = 55;

    if (cpuLoadAverage < 5) newCO = 0;

    if (cpuLoadAverage > 80) newCO = maxCurveOptimizer;

    // Apply new CO
    if (newCO != previousCurveOptimizer) {
      print('Apply new CO: $newCO');
      if (isPerCore) {
        return (prevCpuLoadAverage, RyzenAdjWrapper.applyCurveOptimizerPerCore(newCO, core));
      }
      return (prevCpuLoadAverage, RyzenAdjWrapper.applyCurveOptimizerAllCores(newCO));
    }
    return (prevCpuLoadAverage, previousCurveOptimizer);
}

