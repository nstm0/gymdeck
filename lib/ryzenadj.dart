import 'dart:io' show File, Platform, Process;

class RyzenAdjWrapper{
  static void applyPowerSettings(int tdp, int maxTemperature) {
    List<String> arguments = "--tctl-temp=$maxTemperature --apu-skin-temp=$maxTemperature --stapm-limit=$tdp --fast-limit=$tdp --stapm-time=64 --slow-limit=$tdp --slow-time=128 --vrm-current=300000 --vrmmax-current=300000 --vrmsoc-current=300000 --vrmsocmax-current=300000".split(' ');
    var proc = Process.runSync('${File.fromUri(Platform.script).parent.path}/ryzenadj', arguments);
    print(proc.stderr);
  }

  static int applyCurveOptimizerAllCores(int curveOptimizer) {
    String arguments;
    if (curveOptimizer > 0) {
      arguments = "--set-coall=0x${(0x100000 - curveOptimizer).toRadixString(16)}";
      print('New CO: 0x${(0x100000 - curveOptimizer).toRadixString(16)}');
    }
    else {
      arguments = "--set-coall=0";
    }

    var proc = Process.runSync('${File.fromUri(Platform.script).parent.path}/ryzenadj', [arguments]);
    print(proc.stderr);

    // Save new CO to avoid unnecessary reapplies
    return curveOptimizer;
  }

  static int applyCurveOptimizerPerCore(int curveOptimizer, int core) {
    String arguments;
    if (curveOptimizer > 0) {
      arguments = "-y --core$core $curveOptimizer";
      print('New CO for Core $core: $curveOptimizer');
    }
    else {
      arguments = "-y --core$core 0";
    }

    var proc = Process.runSync('${File.fromUri(Platform.script).parent.path}/ryzenadjcoper', [arguments]);
    print(proc.stderr);

    // Save new CO to avoid unnecessary reapplies
    return curveOptimizer;
  }
}