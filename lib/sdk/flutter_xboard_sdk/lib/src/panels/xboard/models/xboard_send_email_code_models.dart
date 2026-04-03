import 'package:freezed_annotation/freezed_annotation.dart';

part 'xboard_send_email_code_models.freezed.dart';
part 'xboard_send_email_code_models.g.dart';

/// 验证码发送响应
@freezed
class VerificationCodeResponse with _$VerificationCodeResponse {
  const factory VerificationCodeResponse({
    required bool success,
    String? message,
  }) = _VerificationCodeResponse;

  factory VerificationCodeResponse.fromJson(Map<String, dynamic> json) => _$VerificationCodeResponseFromJson(json);
}

/// SendEmailCodeResult 别名（向后兼容）
typedef SendEmailCodeResult = VerificationCodeResponse;