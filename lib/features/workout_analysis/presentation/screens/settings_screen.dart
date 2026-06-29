import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _audioFeedback = true;
  bool _vibration = true;
  bool _darkTheme = true;
  double _sensitivity = 0.7;
  String _cameraPreference = 'Ön kamera';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _SettingsSection(
            title: 'Geri bildirim',
            children: [
              SwitchListTile(
                value: _audioFeedback,
                onChanged: (value) => setState(() => _audioFeedback = value),
                title: const Text('Sesli geri bildirim'),
                activeThumbColor: Colors.greenAccent,
              ),
              SwitchListTile(
                value: _vibration,
                onChanged: (value) => setState(() => _vibration = value),
                title: const Text('Titreşim'),
                activeThumbColor: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Görünüm',
            children: [
              SwitchListTile(
                value: _darkTheme,
                onChanged: (value) => setState(() => _darkTheme = value),
                title: const Text('Koyu tema'),
                activeThumbColor: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Analiz',
            children: [
              ListTile(
                title: const Text('Analiz hassasiyeti'),
                subtitle: Slider(
                  value: _sensitivity,
                  onChanged: (value) => setState(() => _sensitivity = value),
                  activeColor: Colors.greenAccent,
                ),
              ),
              ListTile(
                title: const Text('Kamera tercihi'),
                subtitle: Text(_cameraPreference),
                trailing: DropdownButton<String>(
                  value: _cameraPreference,
                  dropdownColor: const Color(0xFF202020),
                  items: const [
                    DropdownMenuItem(
                      value: 'Ön kamera',
                      child: Text('Ön kamera'),
                    ),
                    DropdownMenuItem(
                      value: 'Arka kamera',
                      child: Text('Arka kamera'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _cameraPreference = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
