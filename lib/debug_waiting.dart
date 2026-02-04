import 'package:flutter/material.dart';
import '../pages/waiting_room_page.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: WaitingRoomPage(status: WaitingRoomStatus.pending),
  ));
}