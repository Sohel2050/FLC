import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
final class Env {
  @EnviedField(varName: "ZEGO_APP_ID")
  static int zegoAppId = _Env.zegoAppId;
  @EnviedField(varName: "ZEGO_APP_SIGN")
  static String zegoAppSign = _Env.zegoAppSign;
}
