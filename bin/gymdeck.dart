import 'dart:io';
import 'dart:math';
import 'package:gymdeck/ryzenadj.dart';
import 'package:gymdeck/sysres/base.dart';

import 'settings.dart';


void main() async {
  await SystemResources.init(); //init cpuLoadAverage module

  Settings settings = Settings().init();

  int previousCurveOptimizer = 0; //kurwas
  List<int> perCorePreviousCurveOptimizer = List.filled(settings.perCoreCurveOptimizerCoreCount, 0); // kurwas per core
  int prevCpuLoadAverage = -1; //percents
  List<int> perCorePreviousCpuLoadAverage = List.filled(settings.perCoreCurveOptimizerCoreCount, -1); // percents per core

  //Create PID file for experimental helper;
  var file = File('${File.fromUri(Platform.script).parent.path}/gymdeck.pid');
  file.writeAsStringSync(pid.toString());

  ProcessSignal.sigusr1.watch().listen((event) {settings.isNotAllowedToRun = false;});
  ProcessSignal.sigusr2.watch().listen((event) {settings = Settings().init();});

  while (true) {
    if (!settings.isNotAllowedToRun) {
      String temperatureFileContent = File('/sys/class/thermal/thermal_zone0/temp').readAsStringSync();
      int temperature = int.parse(temperatureFileContent) ~/ 1000;
      int cpuLoadAverage = (SystemResources.cpuLoadAvg() * 100).toInt();

      //Process TDP works
      //currentPowerLimit = processTDP(temperature, cpuLoadAverage, maxTemperature, currentPowerLimit, minPowerLimit, maxPowerLimit, powerLimitChangeStep);
      if (settings.curveOptimizerType == 1) {
        for (int i = 0; i < settings.perCoreCurveOptimizerCoreCount; i++){
          (prevCpuLoadAverage, previousCurveOptimizer) = processCO(
              temperature,
              cpuLoadAverage,
              settings.perCoreCurveOptimizerSets[i]['max'],
              settings.curveOptimizerChangeStep,
              perCorePreviousCurveOptimizer[i],
              perCorePreviousCpuLoadAverage[i],
              settings.perCoreCurveOptimizerSets[i]['min'],
              true,
              i);
          perCorePreviousCurveOptimizer[i] = previousCurveOptimizer;
          perCorePreviousCpuLoadAverage[i] = prevCpuLoadAverage;
        }
      } else {
        (prevCpuLoadAverage, previousCurveOptimizer) = processCO(
            temperature,
            cpuLoadAverage,
            settings.maxAllCoreCurveOptimizer,
            settings.curveOptimizerChangeStep,
            previousCurveOptimizer,
            prevCpuLoadAverage,
            settings.minAllCoreCurveOptimiser,
            false,
            0);
      }
    } else {

    }
    await Future.delayed(settings.delayTime);
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

