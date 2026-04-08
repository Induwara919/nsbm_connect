import 'dart:math';
import 'smtp_service.dart';

String? generatedOtp;
String? otpEmail;

Future<void> sendOtp({required String email}) async {
  otpEmail = email;
  generatedOtp = (Random().nextInt(900000) + 100000).toString().trim();

  String subject = "Your OTP";
  String body = "Your OTP is $generatedOtp";

  await SmtpService.sendEmail(toEmail: email, subject: subject, body: body);
}

bool verifyOtp({required String email, required String otp}) {
  return otpEmail == email && generatedOtp == otp;
}
