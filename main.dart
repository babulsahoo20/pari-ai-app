import 'dart:io';
import 'lib/brain/pari_brain.dart';

void main() async {
  final brain = PariBrain();

  print("Pari AI Started 💕");

  while (true) {
    stdout.write("You: ");
    final input = stdin.readLineSync();

    if (input == null || input.toLowerCase() == 'exit') break;

    final reply = await brain.chat(input);
    print("Pari: $reply");
  }
}
