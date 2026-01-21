import 'package:flutter/material.dart';

/// A widget that displays export progress for a specific data type
class ExportProgressWidget extends StatelessWidget {
  final String label;
  final int current;
  final int total;
  final bool isLoading;

  const ExportProgressWidget({
    Key? key,
    required this.label,
    required this.current,
    required this.total,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $current/${isLoading ? '(loading...)' : total.toString()}'),
      ],
    );
  }
}

/// A widget that displays overall export progress with multiple data types
class OverallExportProgressWidget extends StatelessWidget {
  final int contactsExported;
  final int contactsTotal;
  final int smsExported;
  final int smsTotal;
  final int callLogsExported;
  final int callLogsTotal;

  const OverallExportProgressWidget({
    Key? key,
    required this.contactsExported,
    required this.contactsTotal,
    required this.smsExported,
    required this.smsTotal,
    required this.callLogsExported,
    required this.callLogsTotal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Export Progress:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ExportProgressWidget(
          label: 'Contacts',
          current: contactsExported,
          total: contactsTotal,
        ),
        ExportProgressWidget(
          label: 'SMS Messages',
          current: smsExported,
          total: smsTotal,
          isLoading: smsTotal == 0,
        ),
        ExportProgressWidget(
          label: 'Call Logs',
          current: callLogsExported,
          total: callLogsTotal,
          isLoading: callLogsTotal == -1,
        ),
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
      ],
    );
  }
}

/// A widget that displays import progress
class ImportProgressWidget extends StatelessWidget {
  final int contactsImported;
  final int contactsTotal;

  const ImportProgressWidget({
    Key? key,
    required this.contactsImported,
    required this.contactsTotal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Import Progress:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('Contacts: $contactsImported/$contactsTotal'),
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
      ],
    );
  }
}
