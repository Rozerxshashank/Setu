import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteMemberScreen extends StatelessWidget {
  const InviteMemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const inviteCode = 'SETU-89214';
    const inviteUrl = 'https://setu.app/join/$inviteCode';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Family Members'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/create_circle');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.share_outlined, size: 64, color: Colors.indigo),
            const SizedBox(height: 24),
            const Text(
              'Share the Responsibility',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Invite your siblings and family caregivers to this circle so everyone gets daily check-in health updates.',
              style: TextStyle(fontSize: 15, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'Family Invite Code',
                    style: TextStyle(fontSize: 14, color: Colors.indigo, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    inviteCode,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text(
                'Copy Invite Link',
                style: TextStyle(fontSize: 18),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: inviteUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invite link copied to clipboard! (https://setu.app/join/SETU-89214)'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 60),
              ),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/circle_summary');
              },
              child: const Text(
                'Continue to Summary',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
