import 'dart:io';

void main() {
  var file = File('${File.fromUri(Platform.script).parent.path}/gymdeck.pid');
  var pid = int.tryParse(file.readAsStringSync());

  if (pid != null) {
    Process.killPid(pid, ProcessSignal.sigusr1);
    print('Сигнал SIGUSR1 отправлен процессу с PID $pid');
  } else {
    print('Не удалось прочитать PID из файла');
  }
}