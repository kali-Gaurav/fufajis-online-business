import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../services/printer_service.dart';
import '../../utils/app_theme.dart';

class PrinterSelectDialog extends StatefulWidget {
  final Function(BluetoothDevice) onDeviceSelected;

  const PrinterSelectDialog({super.key, required this.onDeviceSelected});

  @override
  State<PrinterSelectDialog> createState() => _PrinterSelectDialogState();
}

class _PrinterSelectDialogState extends State<PrinterSelectDialog> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothDevice> _devices = [];
  bool _isLoading = false;
  bool _isConnected = false;
  String _selectedWidth = '58mm';
  String? _defaultAddress;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final devices = await _printerService.getDevices();
      final isConnected = await _printerService.bluetooth.isConnected ?? false;
      final defaultAddress = await _printerService.getDefaultPrinterAddress();
      final defaultWidth = await _printerService.getDefaultPrinterWidth();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isConnected = isConnected;
        _selectedWidth = defaultWidth;
        _defaultAddress = defaultAddress;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load Bluetooth devices: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    try {
      _printerService.printerWidth = _selectedWidth;
      final isConnected = await _printerService.bluetooth.isConnected ?? false;
      if (!isConnected) {
        await _printerService.bluetooth.connect(device);
      }

      // Save device as default
      await _printerService.saveDefaultPrinter(device, _selectedWidth);

      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
      widget.onDeviceSelected(device);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to printer: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Select Printer'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _loadDevices),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Printer Roll Size:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedWidth,
                  items: const [
                    DropdownMenuItem(value: '58mm', child: Text('58mm (2-inch)')),
                    DropdownMenuItem(value: '80mm', child: Text('80mm (3-inch)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedWidth = val;
                      });
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _devices.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'No bonded devices found.\nPlease pair your printer in your system settings first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isDefault = device.address == _defaultAddress;
                        return ListTile(
                          leading: Icon(Icons.print, color: isDefault ? AppTheme.success : null),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  device.name ?? 'Unknown Device',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(device.address ?? ''),
                          trailing: ElevatedButton(
                            onPressed: () => _connectToDevice(device),
                            style: isDefault
                                ? ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                  )
                                : null,
                            child: Text(isDefault && _isConnected ? 'Connected' : 'Connect'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
