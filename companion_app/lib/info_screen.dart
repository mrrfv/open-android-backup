import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const [
              Icon(Icons.backup, size: 28, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Open Android Backup",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Open Android Backup is a tiny shell script & Flutter app that makes securely backing up Android devices easy, without vendor lock-ins or using closed-source software that could put your data at risk.",
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Icon(Icons.info_outline, size: 28, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "About this app",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "The Open Android Backup companion app allows for backups of data not normally accessible through adb. No data is uploaded to a remote server: it is saved to the internal storage and then read by the script running on your computer.",
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Icon(Icons.code, size: 28, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Open Source",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Both the app and script are open-source and available on GitHub. Contributions are welcome!",
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: InkWell(
              onTap: () async {
                final url = Uri.parse('https://github.com/mrrfv/open-android-backup');
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.link, color: Colors.green),
                  SizedBox(width: 6),
                  Text(
                    'View on GitHub',
                    style: TextStyle(
                      color: Colors.green,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
