import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<void> printOrderReceipt(BluetoothDevice device, OrderModel order) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == false) {
        await bluetooth.connect(device);
      }

      bluetooth.printNewLine();
      bluetooth.printCustom("FUFAJI ONLINE", 3, 1); // Size 3, Center
      bluetooth.printCustom("Your District Shop", 1, 1);
      bluetooth.printNewLine();
      
      bluetooth.printCustom("Order: #${order.orderNumber}", 1, 0);
      bluetooth.printCustom("Date: ${DateFormat('dd-MM-yyyy HH:mm').format(order.createdAt)}", 1, 0);
      bluetooth.printCustom("Customer: ${order.customerName}", 1, 0);
      bluetooth.printCustom("-" * 32, 1, 1);
      
      for (var item in order.items) {
        if (!item.isOutOfStock) {
          bluetooth.printLeftRight("${item.productName} x${item.quantity}", "Rs.${item.totalPrice}", 1);
        }
      }
      
      bluetooth.printCustom("-" * 32, 1, 1);
      bluetooth.printCustom("TOTAL AMOUNT: Rs.${order.totalAmount}", 2, 0);
      bluetooth.printCustom("Payment: ${order.paymentMethod.toString().split('.').last.toUpperCase()}", 1, 0);
      bluetooth.printNewLine();
      
      bluetooth.printCustom("Thank you for shopping!", 1, 1);
      bluetooth.printCustom("Sourcing Local, Serving Digital", 0, 1);
      
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } catch (e) {
      throw Exception('Printer Error: $e');
    }
  }
}
