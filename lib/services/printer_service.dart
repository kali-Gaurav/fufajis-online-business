import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  String printerWidth = '58mm';
  int get lineWidth => printerWidth == '80mm' ? 48 : 32;

  static const String _keyPrinterAddress = 'default_printer_address';
  static const String _keyPrinterName = 'default_printer_name';
  static const String _keyPrinterWidth = 'default_printer_width';

  Future<void> saveDefaultPrinter(BluetoothDevice device, String width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterAddress, device.address ?? '');
    await prefs.setString(_keyPrinterName, device.name ?? '');
    await prefs.setString(_keyPrinterWidth, width);
    printerWidth = width;
  }

  Future<String?> getDefaultPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterAddress);
  }

  Future<String?> getDefaultPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterName);
  }

  Future<String> getDefaultPrinterWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getString(_keyPrinterWidth) ?? '58mm';
    printerWidth = width;
    return width;
  }

  Future<void> clearDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPrinterAddress);
    await prefs.remove(_keyPrinterName);
    await prefs.remove(_keyPrinterWidth);
  }

  Future<BluetoothDevice?> getSavedDevice() async {
    final address = await getDefaultPrinterAddress();
    if (address == null || address.isEmpty) return null;
    
    final devices = await getDevices();
    for (var device in devices) {
      if (device.address == address) {
        return device;
      }
    }
    return null;
  }

  Future<bool> connectToSavedDevice() async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == true) {
        await getDefaultPrinterWidth();
        return true;
      }
      
      final device = await getSavedDevice();
      if (device == null) return false;
      
      await bluetooth.connect(device);
      await getDefaultPrinterWidth();
      return true;
    } catch (e) {
      return false;
    }
  }

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
      bluetooth.printCustom("-" * lineWidth, 1, 1);
      
      for (var item in order.items) {
        if (!item.isOutOfStock) {
          bluetooth.printLeftRight("${item.productName} x${item.quantity}", "Rs.${item.totalPrice}", 1);
        }
      }
      
      bluetooth.printCustom("-" * lineWidth, 1, 1);
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

  Future<void> printProductTag(BluetoothDevice device, {
    required String productName,
    required double price,
    required double? originalPrice,
    required String barcode,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == false) {
        await bluetooth.connect(device);
      }

      bluetooth.printNewLine();
      bluetooth.printCustom("FUFAJI ONLINE", 2, 1);
      bluetooth.printCustom("-" * lineWidth, 1, 1);
      
      bluetooth.printCustom(productName, 1, 1);
      if (originalPrice != null && originalPrice > price) {
        bluetooth.printCustom("MRP: Rs. ${originalPrice.toStringAsFixed(2)}", 1, 1);
        bluetooth.printCustom("OFFER PRICE: Rs. ${price.toStringAsFixed(2)}", 2, 1);
      } else {
        bluetooth.printCustom("PRICE: Rs. ${price.toStringAsFixed(2)}", 2, 1);
      }
      
      if (batchNumber != null) {
        bluetooth.printCustom("Batch: $batchNumber", 1, 1);
      }
      if (expiryDate != null) {
        bluetooth.printCustom("Exp: ${DateFormat('dd-MM-yyyy').format(expiryDate)}", 1, 1);
      }
      
      bluetooth.printCustom("-" * lineWidth, 1, 1);
      bluetooth.printCustom("Barcode: $barcode", 1, 1);
      
      // Note: blue_thermal_printer might have different method names depending on version
      // Fallback to text if printBarcode is not available in this version
      bluetooth.printCustom(barcode, 1, 1);
      
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } catch (e) {
      throw Exception('Printer Error: $e');
    }
  }

  Future<void> printParcelTag(BluetoothDevice device, {
    required String parcelId,
    required String orderNumber,
    required String customerName,
    required String customerPhone,
    required String address,
  }) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == false) {
        await bluetooth.connect(device);
      }

      bluetooth.printNewLine();
      bluetooth.printCustom("FUFAJI PARCEL", 2, 1);
      bluetooth.printCustom("-" * lineWidth, 1, 1);
      
      bluetooth.printCustom("Parcel ID: $parcelId", 1, 1);
      bluetooth.printCustom("Order: #$orderNumber", 1, 1);
      bluetooth.printCustom("-" * lineWidth, 1, 1);
      
      bluetooth.printCustom("To: $customerName", 1, 0);
      bluetooth.printCustom("Phone: $customerPhone", 1, 0);
      bluetooth.printCustom("Address: $address", 1, 0);
      bluetooth.printCustom("-" * lineWidth, 1, 1);
      
      // Print QR code for Parcel ID
      await bluetooth.printQRcode(parcelId, 200, 200, 1);
      
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } catch (e) {
      throw Exception('Printer Error: $e');
    }
  }
}
