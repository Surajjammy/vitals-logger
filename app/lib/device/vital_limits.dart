/// Clinic-style plausible ranges. Values outside them are probably a bad
/// measurement or a typo, so we ask once before saving.
class VitalLimits {
  static const systolic = (min: 70, max: 250);
  static const diastolic = (min: 40, max: 150);
  static const pulse = (min: 30, max: 220);
  static const temperatureF = (min: 93.0, max: 106.0);

  /// Human-readable problems; empty when everything is in range.
  static List<String> check({
    int? sys,
    int? dia,
    int? pulseBpm,
    double? tempF,
  }) {
    return [
      if (sys != null && (sys < systolic.min || sys > systolic.max))
        'systolic $sys (expected ${systolic.min}-${systolic.max})',
      if (dia != null && (dia < diastolic.min || dia > diastolic.max))
        'diastolic $dia (expected ${diastolic.min}-${diastolic.max})',
      if (pulseBpm != null && (pulseBpm < pulse.min || pulseBpm > pulse.max))
        'pulse $pulseBpm (expected ${pulse.min}-${pulse.max})',
      if (tempF != null &&
          (tempF < temperatureF.min || tempF > temperatureF.max))
        'temperature $tempF (expected ${temperatureF.min}-${temperatureF.max})',
    ];
  }
}
