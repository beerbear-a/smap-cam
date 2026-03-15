import 'package:flutter/foundation.dart';

const bool devModeBypassesExperienceRules = bool.fromEnvironment(
  'ZOOTOCAM_DEV_MODE',
  defaultValue: !kReleaseMode && !bool.fromEnvironment('FLUTTER_TEST'),
);

const bool enforceAnalogExperienceRules = !devModeBypassesExperienceRules;
const int instantBatteryCapacity = 100;
