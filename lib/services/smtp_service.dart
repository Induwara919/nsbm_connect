import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class SmtpService {
  static Future<void> sendEmail({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('smtp_config')
          .doc('main')
          .get();

      if (!doc.exists) {
        throw Exception("SMTP config not found in Firestore!");
      }

      final config = doc.data()!;

      final username = config['username'] as String;
      final password = config['password'] as String;
      final smtpHost = config['smtp_host'] as String? ?? 'smtp.gmail.com';
      final smtpPort = int.parse(config['smtp_port'] as String? ?? '587');

      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: username,
        password: password,
      );

      final message = Message()
        ..from = Address(username)
        ..recipients.add(toEmail)
        ..subject = subject
        ..text = body;

      final sendReport = await send(message, smtpServer);
      print('Email sent: $sendReport');

    } catch (e) {
      print('Failed to send email: $e');
    }
  }
}
