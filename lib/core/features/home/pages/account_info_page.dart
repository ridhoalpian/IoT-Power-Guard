import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/home_widgets.dart';

class AccountInfoPage extends StatelessWidget {
  const AccountInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Belum tersedia';
    final createdAt = user?.metadata.creationTime;
    final lastSignIn = user?.metadata.lastSignInTime;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SectionTitle(title: 'Informasi Akun'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A7A6F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF0A7A6F),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengguna IoT Power Guard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: email,
        ),
        const SizedBox(height: 12),
        const InfoTile(
          icon: Icons.verified_user_outlined,
          label: 'Status',
          value: 'Aktif',
        ),
        const SizedBox(height: 12),
        InfoTile(
          icon: Icons.calendar_today_outlined,
          label: 'Terdaftar',
          value: createdAt == null ? 'Belum tersedia' : formatDateTime(createdAt),
        ),
        const SizedBox(height: 12),
        InfoTile(
          icon: Icons.update_outlined,
          label: 'Login Terakhir',
          value: lastSignIn == null ? 'Belum tersedia' : formatDateTime(lastSignIn),
        ),
      ],
    );
  }
}
